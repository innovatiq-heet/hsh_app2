package com.example.hsh_app2.screentime

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast
import com.example.hsh_app2.R
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
 *
 * While this service is not connected, [UsageAppBlocker] enforces the same
 * rules from usage events instead.
 */
class AppBlockerAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AppBlockerService"
        private const val DEBOUNCE_MS = 800L
        private const val MAX_ACTIVITY_CACHE = 512
        private const val MAX_NODES_SCANNED = 400
        private val GUARD_CHECK_DELAYS_MS = longArrayOf(0L, 250L, 700L, 1500L)
        /** The Active apps list fills in just after its panel opens; look early and often. */
        private val PANEL_CHECK_DELAYS_MS = longArrayOf(0L, 100L, 250L, 500L, 1000L, 1500L)
        /** Lets Back close the panel before the shade itself is collapsed. */
        private const val COLLAPSE_SHADE_DELAY_MS = 150L

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

        /**
         * Whether the service is running in this process now. Unlike [isEnabled]
         * this is false when Settings lists it as on but Android has not bound
         * it (crashed, "not working"); [UsageAppBlocker] enforces then.
         */
        fun isConnected(): Boolean = instance != null

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
    private var lastGuardAt = 0L
    private var lastPanelGuardAt = 0L

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
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
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
        // Switched off: the usage-events blocker takes over at once.
        PolicyPollService.resumeUsageBlocker()
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        ensureBackgroundSync()
        if (pkg in SelfProtection.SETTINGS_PACKAGES) guardOwnAppInfo()
        if (pkg in SelfProtection.SYSTEM_UI_PACKAGES) guardActiveAppsPanel()
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

    /**
     * Sends the student home if Settings is showing *this app's* App info page,
     * where Force stop / Uninstall would switch the parent lock off. The page's
     * content isn't loaded yet when the window opens, so look a few times.
     */
    private fun guardOwnAppInfo() {
        if (!PolicyStore.hasSession(this) || SelfProtection.inGrace()) return
        for (delay in GUARD_CHECK_DELAYS_MS) {
            mainHandler.postDelayed({ checkOwnAppInfo() }, delay)
        }
    }

    private fun checkOwnAppInfo() {
        if (SelfProtection.inGrace()) return
        val root = rootInActiveWindow ?: return
        if (root.packageName?.toString() !in SelfProtection.SETTINGS_PACKAGES) return
        val texts = ArrayList<String>()
        collectTexts(root, texts)
        val appLabel = applicationInfo.loadLabel(packageManager).toString()
        if (!SelfProtection.isOwnAppDetailsPage(texts, appLabel, SelfProtection.dangerLabels(this))) return

        val now = System.currentTimeMillis()
        if (now - lastGuardAt < DEBOUNCE_MS) return
        lastGuardAt = now
        Log.w(TAG, "Blocked access to own App info page")
        performGlobalAction(GLOBAL_ACTION_HOME)
        Toast.makeText(this, R.string.app_info_protected, Toast.LENGTH_LONG).show()
    }

    /**
     * Closes the notification shade's Active apps panel (Android 13+) while it
     * offers a Stop button for this app. Stop kills the whole app, and Android
     * shows it for every ordinary app with a foreground service.
     */
    private fun guardActiveAppsPanel() {
        if (!PolicyStore.hasSession(this)) return
        for (delay in PANEL_CHECK_DELAYS_MS) {
            mainHandler.postDelayed({ checkActiveAppsPanel() }, delay)
        }
    }

    private fun checkActiveAppsPanel() {
        if (!PolicyStore.hasSession(this)) return
        val appLabel = applicationInfo.loadLabel(packageManager).toString()
        val stopLabels = SelfProtection.stopLabels(this)
        for (root in systemUiRoots()) {
            // Two cheap searches first, so an ordinary shade pull doesn't walk the whole tree.
            if (!mentionsAny(root, stopLabels) || !mentionsAny(root, listOf(appLabel))) continue
            if (!SelfProtection.offersToStopOwnApp(snapshot(root), appLabel, stopLabels)) continue

            val now = System.currentTimeMillis()
            if (now - lastPanelGuardAt < DEBOUNCE_MS) return
            lastPanelGuardAt = now
            Log.w(TAG, "Closed the Active apps panel: it offered to stop this app")
            performGlobalAction(GLOBAL_ACTION_BACK)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                mainHandler.postDelayed(
                    { performGlobalAction(GLOBAL_ACTION_DISMISS_NOTIFICATION_SHADE) },
                    COLLAPSE_SHADE_DELAY_MS,
                )
            }
            Toast.makeText(this, getString(R.string.stop_app_protected, appLabel), Toast.LENGTH_LONG).show()
            return
        }
    }

    /**
     * Every SystemUI window on screen (shade, panels, dialogs). The window list
     * needs `flagRetrieveInteractiveWindows`; the active window covers devices
     * that haven't picked that flag up yet.
     */
    private fun systemUiRoots(): List<AccessibilityNodeInfo> {
        val roots = ArrayList<AccessibilityNodeInfo>()
        runCatching { windows }.getOrNull()?.forEach { w -> runCatching { w.root }.getOrNull()?.let(roots::add) }
        rootInActiveWindow?.let(roots::add)
        return roots
            .filter { it.packageName?.toString() in SelfProtection.SYSTEM_UI_PACKAGES }
            .distinctBy { it.windowId }
    }

    /** Case-insensitive "contains" search done by the system in one call. */
    private fun mentionsAny(root: AccessibilityNodeInfo, words: Collection<String>): Boolean =
        words.any { w ->
            w.isNotBlank() && runCatching { root.findAccessibilityNodeInfosByText(w) }.getOrNull()?.isNotEmpty() == true
        }

    /** Copies the window's node tree for [SelfProtection], capped like [collectTexts]. */
    private fun snapshot(root: AccessibilityNodeInfo): SelfProtection.ScreenNode {
        var budget = MAX_NODES_SCANNED
        fun copy(node: AccessibilityNodeInfo): SelfProtection.ScreenNode {
            budget--
            val texts = listOfNotNull(node.text?.toString(), node.contentDescription?.toString())
            val children = ArrayList<SelfProtection.ScreenNode>()
            for (i in 0 until node.childCount) {
                if (budget <= 0) break
                node.getChild(i)?.let { children.add(copy(it)) }
            }
            return SelfProtection.ScreenNode(texts, children)
        }
        return copy(root)
    }

    /** Breadth-first, capped, so a huge Settings list can't stall the main thread. */
    private fun collectTexts(root: AccessibilityNodeInfo, out: MutableList<String>) {
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var seen = 0
        while (queue.isNotEmpty() && seen++ < MAX_NODES_SCANNED) {
            val node = queue.removeFirst()
            node.text?.toString()?.let { out.add(it) }
            node.contentDescription?.toString()?.let { out.add(it) }
            for (i in 0 until node.childCount) node.getChild(i)?.let { queue.add(it) }
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
}
