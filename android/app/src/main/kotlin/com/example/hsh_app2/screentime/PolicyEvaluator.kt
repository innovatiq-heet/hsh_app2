package com.example.hsh_app2.screentime

import android.app.role.RoleManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import java.util.Calendar

/** Why an app was stopped — surfaced on the block screen and in the audit log. */
enum class BlockReason(val wireName: String, val tag: String, val title: String, val message: String) {
    DEVICE_LOCKED(
        "device_locked", "DEVICE REMOTELY LOCKED", "Phone Locked",
        "Your device has been remotely locked by hostel administration.",
    ),
    APP_BLOCKED(
        "app_blocked", "HOSTEL POLICY ENFORCEMENT", "App Restricted",
        "This app has been restricted by hostel policy.",
    ),
    BEDTIME(
        "bedtime", "CURFEW HOURS", "Curfew Active",
        "Phone use is not allowed during hostel curfew hours.",
    ),
    DAILY_LIMIT(
        "daily_limit", "DAILY LIMIT REACHED", "Screen Time Over",
        "You have used up today's screen-time allowance.",
    );

    companion object {
        fun fromWire(name: String?): BlockReason? = entries.firstOrNull { it.wireName == name }
    }
}

/**
 * Decides whether a package may be in the foreground right now, given the
 * stored [DevicePolicy]. All four rules are enforced on-device so they work
 * offline and don't depend on the backend's clock.
 */
object PolicyEvaluator {
    private const val PROTECTED_CACHE_MS = 5 * 60 * 1000L
    private const val USAGE_CACHE_MS = 60 * 1000L

    /** Packages that must always stay reachable: no phone becomes a brick. */
    private val ALWAYS_PROTECTED = setOf(
        "android",
        "com.android.systemui",
        "com.android.settings",
        "com.samsung.android.settings",
        "com.android.providers.settings",
        "com.android.phone",
        "com.android.server.telecom",
        "com.android.emergency",
        "com.android.incallui",
        "com.samsung.android.incallui",
        "com.google.android.dialer",
        "com.android.dialer",
        "com.samsung.android.dialer",
        "com.android.permissioncontroller",
        "com.google.android.permissioncontroller",
        "com.android.packageinstaller",
        "com.google.android.packageinstaller",
        "com.google.android.gms",
    )

    @Volatile private var protectedCache: Set<String> = emptySet()
    @Volatile private var protectedCacheAt = 0L

    @Volatile private var usageMinutesCache = 0
    @Volatile private var usageCacheAt = 0L

    /** Returns the reason to block [packageName], or null if it is allowed. */
    fun evaluate(context: Context, packageName: String): BlockReason? {
        if (packageName == context.packageName) return null
        if (isProtected(context, packageName)) return null

        val policy = PolicyStore.policy(context)
        if (policy.isLocked) return BlockReason.DEVICE_LOCKED
        if (packageName in policy.blockedPackages) return BlockReason.APP_BLOCKED
        if (policy.hasBedtime && isInBedtime(policy)) return BlockReason.BEDTIME
        if (policy.dailyLimitMinutes > 0 && todayMinutes(context) >= policy.dailyLimitMinutes) {
            return BlockReason.DAILY_LIMIT
        }
        return null
    }

    /** Forget cached usage so a fresh sync is reflected immediately. */
    fun invalidateUsage() { usageCacheAt = 0L }

    // ---------- Bedtime ----------

    fun isInBedtime(policy: DevicePolicy, now: Calendar = Calendar.getInstance()): Boolean {
        val start = parseMinutes(policy.bedtimeStart) ?: return false
        val end = parseMinutes(policy.bedtimeEnd) ?: return false
        if (start == end) return false
        val cur = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        // Overnight window (e.g. 23:00 → 05:00) wraps past midnight.
        return if (start < end) cur in start until end else cur >= start || cur < end
    }

    private fun parseMinutes(hhmm: String): Int? {
        val parts = hhmm.trim().split(":")
        if (parts.size < 2) return null
        val h = parts[0].toIntOrNull() ?: return null
        val m = parts[1].take(2).toIntOrNull() ?: return null
        if (h !in 0..23 || m !in 0..59) return null
        return h * 60 + m
    }

    // ---------- Daily limit ----------

    /** Today's total foreground minutes across all non-hostel apps, cached briefly. */
    fun todayMinutes(context: Context): Int {
        val now = System.currentTimeMillis()
        if (now - usageCacheAt < USAGE_CACHE_MS) return usageMinutesCache
        if (!UsageCollector.hasPermission(context)) return 0
        val dayStart = UsageCollector.startOfDay(now)
        val snap = runCatching {
            UsageCollector.collect(context, dayStart, UsageCollector.nextDayStart(dayStart))
        }.getOrNull() ?: return usageMinutesCache
        val total = snap.appMillis.filterKeys { it != context.packageName }.values.sum()
        usageMinutesCache = (total / 60_000L).toInt()
        usageCacheAt = now
        return usageMinutesCache
    }

    // ---------- Protected apps ----------

    fun isProtected(context: Context, packageName: String): Boolean =
        packageName in ALWAYS_PROTECTED || packageName in protectedPackages(context)

    /**
     * Keyboard, dialer, launcher and friends are resolved from the system at
     * runtime instead of hard-coding OEM package names.
     */
    private fun protectedPackages(context: Context): Set<String> {
        val now = System.currentTimeMillis()
        if (now - protectedCacheAt < PROTECTED_CACHE_MS && protectedCache.isNotEmpty()) return protectedCache

        val pm = context.packageManager
        val set = HashSet<String>()

        // Every enabled keyboard — blocking the IME under lock would stop the
        // student typing in *our* app.
        runCatching {
            val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.enabledInputMethodList.forEach { set.add(it.packageName) }
            Settings.Secure.getString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
                ?.let { ComponentName.unflattenFromString(it)?.packageName }
                ?.let { set.add(it) }
        }

        // Home launchers.
        runCatching {
            val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            pm.queryIntentActivities(home, PackageManager.MATCH_ALL).forEach { set.add(it.activityInfo.packageName) }
        }

        // Dialer / in-call UI (so incoming calls are never blocked).
        runCatching {
            pm.resolveActivity(Intent(Intent.ACTION_DIAL), PackageManager.MATCH_DEFAULT_ONLY)
                ?.activityInfo?.packageName?.let { set.add(it) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val rm = context.getSystemService(Context.ROLE_SERVICE) as RoleManager
                if (rm.isRoleAvailable(RoleManager.ROLE_DIALER)) {
                    pm.queryIntentActivities(
                        Intent(Intent.ACTION_DIAL), PackageManager.MATCH_DEFAULT_ONLY,
                    ).forEach { set.add(it.activityInfo.packageName) }
                }
            }
            pm.resolveActivity(Intent("android.intent.action.DIAL_EMERGENCY"), PackageManager.MATCH_DEFAULT_ONLY)
                ?.activityInfo?.packageName?.let { set.add(it) }
        }

        protectedCache = set
        protectedCacheAt = now
        return set
    }
}
