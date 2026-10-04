package com.example.hsh_app2.screentime

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.view.accessibility.AccessibilityEvent

/**
 * Watches foreground app changes and enforces the [DevicePolicy] via
 * [PolicyEvaluator]: remote lock, blocked apps, curfew and daily limit.
 */
class AppBlockerAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AppBlockerService"
        private const val DEBOUNCE_MS = 800L

        /** Whether this service is switched on in Settings → Accessibility. */
        fun isEnabled(context: Context): Boolean {
            val expected = ComponentName(context, AppBlockerAccessibilityService::class.java)
            val enabled = Settings.Secure.getString(
                context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            val splitter = TextUtils.SimpleStringSplitter(':')
            splitter.setString(enabled)
            for (entry in splitter) {
                val cn = ComponentName.unflattenFromString(entry) ?: continue
                if (cn == expected) return true
            }
            return false
        }
    }

    private var lastBlockedPkg: String? = null
    private var lastBlockedAt = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        val reason = PolicyEvaluator.evaluate(this, pkg) ?: return

        val now = System.currentTimeMillis()
        if (pkg == lastBlockedPkg && now - lastBlockedAt < DEBOUNCE_MS) return
        lastBlockedPkg = pkg
        lastBlockedAt = now

        val appName = UsageCollector.appLabel(this, pkg)
        Log.w(TAG, "Blocking $pkg (${reason.wireName})")
        PolicyStore.recordBlockEvent(this, pkg, appName, reason)

        // Launch BlockedAppActivity over the restricted app.
        val intent = BlockedAppActivity.intent(this, pkg, appName, reason)
        val started = runCatching {
            startActivity(intent)
            true
        }.getOrElse {
            Log.e(TAG, "BlockedAppActivity failed: ${it.message}")
            false
        }

        // Fallback for ROMs that prevent background activity launches: kick out to Home
        if (!started) {
            runCatching { performGlobalAction(GLOBAL_ACTION_HOME) }
                .onFailure { Log.e(TAG, "GLOBAL_ACTION_HOME fallback failed: ${it.message}") }
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "interrupted")
    }
}
