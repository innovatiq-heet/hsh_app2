package com.example.hsh_app2.screentime

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import java.util.concurrent.Executors

/**
 * Enforces the [DevicePolicy] via [PolicyEvaluator]: remote lock, blocked
 * apps, curfew and daily limit.
 *
 * Two triggers:
 *  - a window change (an app is opened or switched to) → check that app;
 *  - the policy itself changes (warden blocks an app, locks the phone, a gate
 *    pass lands…) or a time-based rule kicks in → re-check the app that is
 *    *already* on screen. Without this, an app restricted while in use stayed
 *    usable until the student left and reopened it.
 */
class AppBlockerAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AppBlockerService"
        private const val DEBOUNCE_MS = 800L
        private const val MAX_ACTIVITY_CACHE = 512

        @Volatile private var instance: AppBlockerAccessibilityService? = null

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

        /** Re-evaluate the app currently on screen. Safe to call from any thread; no-op if the service is off. */
        fun recheckForeground() {
            instance?.enforceForeground()
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    /** Foreground lookup reads usage events; keep it off the main thread. */
    private val lookupExecutor = Executors.newSingleThreadExecutor()

    private var lastBlockedPkg: String? = null
    private var lastBlockedAt = 0L

    /** Package of the last *activity* window shown (dialogs, keyboards and the shade don't count). */
    @Volatile private var foregroundPkg: String? = null
    /** Bumped on every activity switch, so a lookup that raced an app switch is dropped. */
    @Volatile private var switchSeq = 0L
    private val activityCache = HashMap<String, Boolean>()

    /** Policy / geofence-state changes arrive on whatever thread saved them. */
    private val policyListener: () -> Unit = { recheckForeground() }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        PolicyStore.addPolicyListener(policyListener)
        // The service can (re)connect while a restricted app is already open.
        enforceForeground()
    }

    override fun onDestroy() {
        PolicyStore.removePolicyListener(policyListener)
        if (instance === this) instance = null
        mainHandler.removeCallbacksAndMessages(null)
        lookupExecutor.shutdownNow()
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        if (isActivityWindow(pkg, event.className?.toString()) && foregroundPkg != pkg) {
            foregroundPkg = pkg
            switchSeq++
        }
        enforce(pkg)
    }

    override fun onInterrupt() {
        Log.w(TAG, "interrupted")
    }

    /**
     * Blocks the app the student is looking at right now, if the current
     * policy forbids it. The last activity window seen here is real-time and
     * is used first; usage events (which can lag a moment behind a switch) are
     * the fallback when nothing has been seen yet, e.g. the service just
     * (re)connected with an app already open.
     */
    private fun enforceForeground() {
        val seq = switchSeq
        runCatching {
            lookupExecutor.execute {
                if (!UsageCollector.isScreenOn(this)) return@execute
                val pkg = foregroundPkg ?: UsageCollector.foregroundPackage(this) ?: return@execute
                mainHandler.post {
                    // The student switched apps meanwhile; that switch was already enforced.
                    if (seq == switchSeq) enforce(pkg)
                }
            }
        } // RejectedExecutionException once the service is shutting down
    }

    private fun enforce(pkg: String) {
        val reason = PolicyEvaluator.evaluate(this, pkg) ?: return

        val now = System.currentTimeMillis()
        if (pkg == lastBlockedPkg && now - lastBlockedAt < DEBOUNCE_MS) return
        lastBlockedPkg = pkg
        lastBlockedAt = now

        val appName = UsageCollector.appLabel(this, pkg)
        Log.w(TAG, "Blocking $pkg (${reason.wireName})")
        PolicyStore.recordBlockEvent(this, pkg, appName, reason)

        // Kick the restricted app out first, then explain why on top of the launcher.
        runCatching { performGlobalAction(GLOBAL_ACTION_HOME) }
            .onFailure { Log.e(TAG, "GLOBAL_ACTION_HOME failed: ${it.message}") }
        runCatching {
            startActivity(BlockedAppActivity.intent(this, pkg, appName, reason))
        }.onFailure { Log.e(TAG, "BlockedAppActivity failed: ${it.message}") }
    }

    /** Whether the window is a real activity of [pkg] (cached per component). */
    private fun isActivityWindow(pkg: String, className: String?): Boolean {
        if (className.isNullOrEmpty()) return false
        val key = "$pkg/$className"
        activityCache[key]?.let { return it }
        val isActivity = runCatching {
            packageManager.getActivityInfo(ComponentName(pkg, className), 0)
            true
        }.getOrDefault(false)
        if (activityCache.size >= MAX_ACTIVITY_CACHE) activityCache.clear()
        activityCache[key] = isActivity
        return isActivity
    }
}
