package com.example.hsh_app2.screentime

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class AppBlockerAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AppBlockerService"

        /** Essential system packages that must never be locked even during remote device lock */
        private val ESSENTIAL_WHITELIST = setOf(
            "com.android.systemui",
            "android",
            "com.google.android.dialer",
            "com.android.dialer",
            "com.samsung.android.dialer",
            "com.android.phone",
            "com.android.server.telecom",
            "com.google.android.packageinstaller",
            "com.android.packageinstaller"
        )

        /**
         * Checks whether this AccessibilityService is currently enabled in Android Settings.
         */
        fun isEnabled(context: Context): Boolean {
            val expectedServiceName = "${context.packageName}/${AppBlockerAccessibilityService::class.java.canonicalName}"
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false

            val colonSplitter = TextUtils.SimpleStringSplitter(':')
            colonSplitter.setString(enabledServices)
            while (colonSplitter.hasNext()) {
                val componentName = colonSplitter.next()
                if (componentName.equals(expectedServiceName, ignoreCase = true) ||
                    componentName.contains("AppBlockerAccessibilityService", ignoreCase = true)) {
                    return true
                }
            }
            return false
        }
    }

    private var lastBlockedPkg: String? = null
    private var lastBlockedTime: Long = 0

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val pkgName = event.packageName?.toString() ?: return

        // 1. Never block our own app
        if (pkgName == packageName) return

        // 2. Never block essential system components or launchers
        if (isLauncherOrSystem(pkgName)) return

        // 3. Check screen time policy
        val prefs = getSharedPreferences("hsh_screen_time_policy", Context.MODE_PRIVATE)
        val isLocked = prefs.getBoolean("is_locked", false)
        val blockedPackages = prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()

        val isTargetBlocked = blockedPackages.contains(pkgName)
        val isFullDeviceLocked = isLocked && !isDialer(pkgName)

        if (isTargetBlocked || isFullDeviceLocked) {
            val now = System.currentTimeMillis()
            // Debounce rapid repeat triggers for the same package within 1.5 seconds
            if (pkgName == lastBlockedPkg && (now - lastBlockedTime) < 1500) {
                return
            }
            lastBlockedPkg = pkgName
            lastBlockedTime = now

            Log.w(TAG, "Blocking prohibited package: $pkgName (isLocked=$isLocked, inBlockedList=$isTargetBlocked)")

            // Step A: Immediately send user to home screen to close the restricted app
            try {
                performGlobalAction(GLOBAL_ACTION_HOME)
            } catch (e: Exception) {
                Log.e(TAG, "Failed performGlobalAction HOME: ${e.message}")
            }

            // Step B: Show native restriction notification screen
            val appLabel = UsageCollector.appLabel(this, pkgName)
            val blockIntent = Intent(this, BlockedAppActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(BlockedAppActivity.EXTRA_PACKAGE_NAME, pkgName)
                putExtra(BlockedAppActivity.EXTRA_APP_NAME, appLabel)
            }
            try {
                startActivity(blockIntent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start BlockedAppActivity: ${e.message}")
            }
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "AppBlockerAccessibilityService interrupted")
    }

    private fun isDialer(pkg: String): Boolean {
        if (ESSENTIAL_WHITELIST.contains(pkg)) return true
        val telecomIntent = Intent(Intent.ACTION_DIAL)
        val resolveInfo = packageManager.resolveActivity(telecomIntent, PackageManager.MATCH_DEFAULT_ONLY)
        return resolveInfo?.activityInfo?.packageName == pkg
    }

    private fun isLauncherOrSystem(pkg: String): Boolean {
        if (ESSENTIAL_WHITELIST.contains(pkg)) return true

        // Detect default or installed home launchers
        val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val launchers = packageManager.queryIntentActivities(homeIntent, PackageManager.MATCH_DEFAULT_ONLY)
        for (info in launchers) {
            if (info.activityInfo?.packageName == pkg) {
                return true
            }
        }
        return false
    }
}
