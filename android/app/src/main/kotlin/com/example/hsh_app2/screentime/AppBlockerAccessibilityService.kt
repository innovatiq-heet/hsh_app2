package com.example.hsh_app2.screentime

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast
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

    private var lastWatchdogCheckAt = 0L

    /**
     * Self-healing watchdog: ensures PolicyPollService and ScreenTimeSync ticks
     * remain alive even if background app refresh / data was toggled off and on,
     * or if the OS killed the poller.
     */
    private fun ensureBackgroundSync() {
        val now = System.currentTimeMillis()
        if (now - lastWatchdogCheckAt < 15_000L) return
        lastWatchdogCheckAt = now
        if (PolicyStore.hasSession(this)) {
            if (!PolicyPollService.isRunning()) {
                Log.i(TAG, "Reviving PolicyPollService from accessibility watchdog")
                PolicyPollService.start(this)
            }
            ScreenTimeSync.ensureTick(this)
            // Even if PolicyPollService was stopped by Task Manager, fetch the policy
            // directly in the background so the parent lock is ALWAYS kept up-to-date!
            lookupExecutor.execute {
                runCatching {
                    ScreenTimeSync.fetchAndSavePolicy(this@AppBlockerAccessibilityService)
                }
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        val info = serviceInfo
        if (info != null) {
            info.flags = info.flags or AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            serviceInfo = info
        }
        PolicyStore.addPolicyListener(policyListener)
        ensureBackgroundSync()
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
        if (event == null) return
        val eventType = event.eventType
        if (eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) return

        val pkg = event.packageName?.toString() ?: return
        ensureBackgroundSync()

        // Anti-tamper Settings guard: prevent students from force-stopping,
        // uninstalling or disabling HSH security services.
        if (guardSettingsIfTampering(pkg, event)) {
            return
        }

        // App blocker enforcement only evaluates full window state switches
        if (eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

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

        // Launch BlockedAppActivity directly over the restricted application.
        // It displays the restriction message (app name, reason, return home / HSH Seva buttons).
        val launched = runCatching {
            startActivity(BlockedAppActivity.intent(this, pkg, appName, reason))
            true
        }.getOrElse { e ->
            Log.e(TAG, "BlockedAppActivity failed to launch: ${e.message}")
            false
        }

        // Fallback: If BlockedAppActivity could not start, minimize via GLOBAL_ACTION_HOME
        // so the prohibited app cannot remain in use.
        if (!launched) {
            runCatching { performGlobalAction(GLOBAL_ACTION_HOME) }
        }
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

    // region Anti-Tamper Settings Guard
    private var lastSettingsCheckAt = 0L
    private var lastTamperToastAt = 0L

    private fun isSettingsOrInstaller(pkg: String): Boolean {
        if (pkg == "com.android.settings" ||
            pkg == "com.google.android.settings" ||
            pkg == "com.samsung.android.settings" ||
            pkg == "com.android.systemui" ||
            pkg == "com.miui.securitycenter" ||
            pkg == "com.coloros.safecenter" ||
            pkg == "com.coloros.settings" ||
            pkg == "com.vivo.permissionmanager" ||
            pkg == "com.huawei.systemmanager" ||
            pkg == "com.transsion.phonemaster" ||
            pkg == "com.android.packageinstaller" ||
            pkg == "com.google.android.packageinstaller"
        ) {
            return true
        }
        val lower = pkg.lowercase()
        return lower.contains("settings") ||
               lower.contains("safecenter") ||
               lower.contains("securitycenter") ||
               lower.contains("packageinstaller") ||
               lower.contains("systemui")
    }

    /**
     * Intercepts attempts by students to Force-Stop, Uninstall, or toggle off
     * accessibility/security permissions for HSH App in Android Settings while a
     * student session is active. Normal device settings (Wi-Fi, Bluetooth, Sound, Display)
     * remain completely usable.
     */
    private fun guardSettingsIfTampering(pkg: String, event: AccessibilityEvent): Boolean {
        if (!PolicyStore.hasSession(this)) return false
        if (!isSettingsOrInstaller(pkg)) return false

        val now = System.currentTimeMillis()
        val eventType = event.eventType
        // Debounce content-changed events to keep scrolling smooth
        if (eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED && now - lastSettingsCheckAt < 150L) {
            return false
        }
        lastSettingsCheckAt = now

        val root = runCatching { rootInActiveWindow ?: event.source }.getOrNull() ?: return false
        val className = event.className?.toString() ?: ""

        val isTamper = try {
            checkNodeTamper(root, className)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking anti-tamper: ${e.message}")
            false
        }

        if (isTamper) {
            Log.w(TAG, "Anti-tamper triggered on $pkg (class: $className)")
            // 1. Immediately exit the restricted settings screen
            performGlobalAction(GLOBAL_ACTION_BACK)

            // 2. Warn the student
            if (now - lastTamperToastAt > 2000L) {
                lastTamperToastAt = now
                mainHandler.post {
                    Toast.makeText(
                        applicationContext,
                        "Hostel policy: Modifying or force-stopping HSH security settings is restricted.",
                        Toast.LENGTH_SHORT
                    ).show()
                }
            }

            // 3. Fallback: If still on the restricted screen after 250ms, press Home
            mainHandler.postDelayed({
                runCatching {
                    val currentRoot = rootInActiveWindow ?: return@runCatching
                    val currentPkg = currentRoot.packageName?.toString() ?: ""
                    if (isSettingsOrInstaller(currentPkg) && checkNodeTamper(currentRoot, "")) {
                        performGlobalAction(GLOBAL_ACTION_HOME)
                    }
                }
            }, 250L)

            return true
        }
        return false
    }

    private fun checkNodeTamper(root: AccessibilityNodeInfo, className: String): Boolean {
        // Direct package match: In Android Settings, our package name appears on the App Info page
        // (version footer / package details) or uninstaller dialog, never in the general apps list.
        if (hasText(root, "com.example.hsh_app2")) {
            return true
        }

        val hasAppTitle = hasText(root, "HSH App") || hasText(root, "HSH Seva")
        val hasServiceTitle = hasText(root, "HSH App Blocker")

        // SystemUI Task Manager ("Check background activity" / "Active apps" bottom sheet)
        val isTaskManagerSheet = hasText(root, "Check background activity") ||
            hasText(root, "active while running in the background") ||
            hasText(root, "Active apps") ||
            hasText(root, "active app")
        if (isTaskManagerSheet && (hasAppTitle || hasText(root, "Stop"))) {
            return true
        }

        if (!hasAppTitle && !hasServiceTitle) {
            return false
        }

        // If the accessibility service toggle page is open
        if (hasServiceTitle || className.contains("ToggleAccessibility", ignoreCase = true)) {
            return true
        }

        // If it's an App Details / Uninstaller fragment or activity
        val isDetailsClass = className.contains("InstalledAppDetails", ignoreCase = true) ||
            className.contains("AppInfo", ignoreCase = true) ||
            className.contains("ApplicationsDetails", ignoreCase = true) ||
            className.contains("AppDetails", ignoreCase = true) ||
            className.contains("Uninstaller", ignoreCase = true) ||
            className.contains("PackageInstaller", ignoreCase = true)

        if (isDetailsClass && hasAppTitle) {
            return true
        }

        // Action buttons present on App Info pages
        val hasTamperActions = hasText(root, "Force stop") ||
            hasText(root, "Force close") ||
            hasText(root, "Uninstall") ||
            hasText(root, "Clear data") ||
            hasText(root, "Clear storage") ||
            hasText(root, "Disable")

        if (hasTamperActions && hasAppTitle) {
            return true
        }

        return false
    }

    @Suppress("DEPRECATION")
    private fun hasText(root: AccessibilityNodeInfo, text: String): Boolean {
        val list = runCatching { root.findAccessibilityNodeInfosByText(text) }.getOrNull() ?: return false
        val found = list.isNotEmpty()
        for (node in list) {
            runCatching { node.recycle() }
        }
        return found
    }
    // endregion
}
