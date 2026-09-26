package com.example.hsh_app2

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.hsh.app/screentime"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageStatsPermission" -> {
                    result.success(checkUsageStatsPermission())
                }
                "requestUsageStatsPermission" -> {
                    requestUsageStatsPermission()
                    result.success(true)
                }
                "hasOverlayPermission" -> {
                    result.success(checkOverlayPermission())
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(true)
                }
                "getInstalledApps" -> {
                    try {
                        val apps = getInstalledAppsList()
                        result.success(apps)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getTodayAppUsage" -> {
                    try {
                        val usage = getTodayAppUsageList()
                        result.success(usage)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getForegroundApp" -> {
                    try {
                        val currentApp = getForegroundAppPackage()
                        result.success(currentApp)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "syncPolicyToNative" -> {
                    try {
                        val blockedPackages = call.argument<List<String>>("blockedPackages") ?: emptyList()
                        val isLocked = call.argument<Boolean>("isLocked") ?: false
                        val bedtimeStart = call.argument<String>("bedtimeStart") ?: ""
                        val bedtimeEnd = call.argument<String>("bedtimeEnd") ?: ""

                        val prefs = getSharedPreferences("ParentalControlPrefs", Context.MODE_PRIVATE)
                        prefs.edit().apply {
                            putStringSet("blocked_packages", blockedPackages.toSet())
                            putBoolean("is_locked", isLocked)
                            putString("bedtime_start", bedtimeStart)
                            putString("bedtime_end", bedtimeEnd)
                            apply()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun requestUsageStatsPermission() {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback to general settings page if direct package uri is unsupported
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        }
    }

    private fun checkOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                ).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
            } catch (e: Exception) {
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
            }
        }
    }

    private fun getInstalledAppsList(): List<Map<String, String>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = pm.queryIntentActivities(intent, 0)
        val list = mutableListOf<Map<String, String>>()

        for (info in resolveInfos) {
            val pkg = info.activityInfo.packageName
            // Exclude our own app
            if (pkg != packageName) {
                val label = info.loadLabel(pm).toString()
                list.add(mapOf("packageName" to pkg, "appName" to label))
            }
        }
        return list
    }

    private fun getTodayAppUsageList(): List<Map<String, Any>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return emptyList()
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startTime = calendar.timeInMillis
        val endTime = System.currentTimeMillis()

        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
        val pm = packageManager
        val list = mutableListOf<Map<String, Any>>()

        if (stats != null) {
            for (stat in stats) {
                val mins = (stat.totalTimeInForeground / (1000 * 60)).toInt()
                if (mins > 0 && stat.packageName != packageName) {
                    val label = try {
                        val ai = pm.getApplicationInfo(stat.packageName, 0)
                        pm.getApplicationLabel(ai).toString()
                    } catch (e: Exception) {
                        stat.packageName
                    }
                    list.add(
                        mapOf(
                            "packageName" to stat.packageName,
                            "appName" to label,
                            "minutes" to mins
                        )
                    )
                }
            }
        }
        return list
    }

    private fun getForegroundAppPackage(): String {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return ""
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - 1000 * 60 * 5, now)
        val event = UsageEvents.Event()
        var lastPkg = ""

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                lastPkg = event.packageName
            }
        }
        return lastPkg
    }
}
