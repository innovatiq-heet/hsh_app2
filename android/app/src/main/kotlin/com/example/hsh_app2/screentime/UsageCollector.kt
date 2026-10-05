package com.example.hsh_app2.screentime

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.util.Base64
import java.io.ByteArrayOutputStream
import android.os.Build
import android.os.PowerManager
import android.os.Process
import java.util.Calendar

/** Foreground time of every app for one calendar day, read from the OS. */
data class UsageSnapshot(
    /** packageName -> foreground millis within the day. */
    val appMillis: Map<String, Long>,
    /** Package currently in the foreground (null if screen off / launcher). */
    val currentPackage: String?,
    val isScreenOn: Boolean,
)

/**
 * Computes real device screen time from [UsageStatsManager] events.
 *
 * Event-based (RESUMED/PAUSED pairs) rather than `queryUsageStats`, because
 * the daily buckets returned by the latter don't align with local midnight
 * and are notoriously inaccurate on many OEM ROMs.
 */
object UsageCollector {
    // UsageEvents.Event constants (literal values so they work below the API
    // level that introduced the named constants).
    private const val ACTIVITY_RESUMED = 1
    private const val ACTIVITY_PAUSED = 2
    private const val SCREEN_NON_INTERACTIVE = 16
    private const val KEYGUARD_SHOWN = 17
    private const val DEVICE_SHUTDOWN = 26

    /** Look back before midnight so an app already open at 00:00 is counted. */
    private const val LOOKBACK_MS = 6 * 60 * 60 * 1000L

    fun hasPermission(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName,
            )
        }
        return if (mode == AppOpsManager.MODE_DEFAULT) {
            context.checkCallingOrSelfPermission(android.Manifest.permission.PACKAGE_USAGE_STATS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            mode == AppOpsManager.MODE_ALLOWED
        }
    }

    fun isScreenOn(context: Context): Boolean =
        (context.getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive

    /** Local midnight (start of day) for the given instant. */
    fun startOfDay(millis: Long): Long = Calendar.getInstance().run {
        timeInMillis = millis
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
        timeInMillis
    }

    fun nextDayStart(dayStart: Long): Long = Calendar.getInstance().run {
        timeInMillis = dayStart
        add(Calendar.DAY_OF_YEAR, 1)
        timeInMillis
    }

    /**
     * Package whose activity is resumed right now, from usage events. Null
     * without Usage Access, with the screen off, or when nothing was resumed
     * within [lookbackMs] (callers fall back to their own tracking).
     */
    fun foregroundPackage(context: Context, lookbackMs: Long = 3 * 60 * 60 * 1000L): String? {
        if (!isScreenOn(context) || !hasPermission(context)) return null
        val now = System.currentTimeMillis()
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = runCatching { usm.queryEvents(now - lookbackMs, now) }.getOrNull() ?: return null
        val event = UsageEvents.Event()
        var fg: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                ACTIVITY_RESUMED -> fg = event.packageName
                ACTIVITY_PAUSED -> if (fg == event.packageName) fg = null
                SCREEN_NON_INTERACTIVE, KEYGUARD_SHOWN, DEVICE_SHUTDOWN -> fg = null
            }
        }
        return fg
    }

    /** Collects usage for [dayStart, min(dayEnd, now)). */
    fun collect(context: Context, dayStart: Long, dayEnd: Long): UsageSnapshot {
        val now = System.currentTimeMillis()
        val end = minOf(dayEnd, now)
        val screenOn = isScreenOn(context)
        val ignored = ignoredPackages(context)

        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(dayStart - LOOKBACK_MS, end)
        val event = UsageEvents.Event()

        val perApp = HashMap<String, Long>()
        var fgPackage: String? = null
        var fgStart = 0L
        var lastEventTs = dayStart

        fun close(at: Long) {
            val pkg = fgPackage ?: return
            val from = maxOf(fgStart, dayStart)
            val to = minOf(at, end)
            if (to > from && pkg !in ignored) {
                perApp[pkg] = (perApp[pkg] ?: 0L) + (to - from)
            }
            fgPackage = null
        }

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            lastEventTs = event.timeStamp
            when (event.eventType) {
                ACTIVITY_RESUMED -> if (fgPackage != event.packageName) {
                    close(event.timeStamp)
                    fgPackage = event.packageName
                    fgStart = event.timeStamp
                }
                ACTIVITY_PAUSED -> if (fgPackage == event.packageName) close(event.timeStamp)
                SCREEN_NON_INTERACTIVE, KEYGUARD_SHOWN, DEVICE_SHUTDOWN -> close(event.timeStamp)
            }
        }

        // Still-open session: count it up to now only if the screen is really on
        // and we're collecting the current day; otherwise cut it at the last
        // event so a missed "screen off" event can't inflate the total.
        val isLive = dayEnd > now
        val openPackage = fgPackage
        if (openPackage != null) {
            close(if (isLive && screenOn) end else lastEventTs)
        }

        val current = if (isLive && screenOn && openPackage != null && openPackage !in ignored) {
            openPackage
        } else {
            null
        }
        return UsageSnapshot(perApp, current, screenOn && isLive)
    }

    fun appLabel(context: Context, packageName: String): String = try {
        val pm = context.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
    } catch (_: Exception) {
        packageName
    }

    /** Launcher icon as a small base64 PNG (~2–4 KB), or null if the app is gone. */
    fun appIconBase64(context: Context, packageName: String, sizePx: Int = 72): String? = try {
        val drawable = context.packageManager.getApplicationIcon(packageName)
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            Bitmap.createScaledBitmap(drawable.bitmap, sizePx, sizePx, true)
        } else {
            // Adaptive / vector icons have no backing bitmap: rasterise them.
            Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888).also { bmp ->
                val canvas = Canvas(bmp)
                drawable.setBounds(0, 0, sizePx, sizePx)
                drawable.draw(canvas)
            }
        }
        ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
        }
    } catch (_: Exception) {
        null
    }

    /** Home-screen launchers aren't "apps being used" — exclude them. Also exclude our own app. */
    private fun ignoredPackages(context: Context): Set<String> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val launchers = context.packageManager
            .queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
            .map { it.activityInfo.packageName }
        return (launchers + "com.android.systemui" + context.packageName).toSet()
    }
}
