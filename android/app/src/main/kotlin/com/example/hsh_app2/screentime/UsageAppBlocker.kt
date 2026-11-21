package com.example.hsh_app2.screentime

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.provider.Settings
import android.util.Log

/**
 * The app blocker. It uses no Accessibility service: Google Play asks for
 * narrower APIs where they suffice, and some UPI and bank apps refuse to pay
 * while a third-party accessibility service is on.
 *
 * While the screen is on, this reads Android usage events every [TICK_MS] to
 * find the app in front, and opens [BlockedAppActivity] over it when
 * [PolicyEvaluator] forbids it (remote lock, blocked apps, installers, app
 * limits, bedtime, daily limit), logging a block event.
 *
 * Needs Usage access to see the app in front and, on Android 10+, "Display
 * over other apps": without it Android does not let a background app open an
 * activity.
 *
 * Owned by [PolicyPollService]. It stops looking while the screen is off or a
 * permission is missing; [resume] (screen on, service tick, policy change)
 * starts it again.
 */
class UsageAppBlocker(private val context: Context) {

    companion object {
        private const val TAG = "UsageAppBlocker"
        private const val TICK_MS = 1_000L
        /**
         * While Settings is in front: the device admin screen must be covered
         * before the student can tap "Deactivate" ([ProtectedScreens]).
         */
        private const val SETTINGS_TICK_MS = 250L
        /**
         * Android records usage events asynchronously, so each read goes back
         * this far. Replaying events already applied is harmless: the result
         * only depends on the last app resumed and what followed it.
         */
        private const val EVENT_OVERLAP_MS = 5_000L
        /** A longer gap between reads (or the clock going back) means reading the app in front from scratch. */
        private const val MAX_READ_GAP_MS = 60_000L
        /** While a restricted app stays in front, open the block screen again this often. */
        private const val RETRY_MS = 2_000L

        /** Android 10+ lets a background app open an activity only with "Display over other apps". */
        fun canShowBlockScreen(context: Context): Boolean =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || Settings.canDrawOverlays(context)

        /**
         * Opens [BlockedAppActivity] over [pkg] and, when [log], records a block
         * event. Also used by [HshDeviceAdmin] when removal protection is about
         * to be turned off.
         */
        fun showBlockScreen(context: Context, pkg: String, reason: BlockReason, log: Boolean) {
            val appName = UsageCollector.appLabel(context, pkg)
            if (log) {
                Log.w(TAG, "Blocking $pkg (${reason.wireName})")
                PolicyStore.recordBlockEvent(context, pkg, appName, reason)
            }
            runCatching { context.startActivity(BlockedAppActivity.intent(context, pkg, appName, reason)) }
                .onFailure { Log.e(TAG, "BlockedAppActivity failed to launch: ${it.message}") }
            // A try to turn off removal protection is sent at once, not with the next 5-min ping.
            if (log && reason == BlockReason.ADMIN_PROTECTED) {
                runCatching { urgentSync.execute { ScreenTimeSync.syncNow(context.applicationContext) } }
            }
        }

        private val urgentSync = java.util.concurrent.Executors.newSingleThreadExecutor()

        /** Whether the phone has what the blocker needs (Usage access, Display over other apps). */
        fun isReady(context: Context): Boolean =
            UsageCollector.hasPermission(context) && canShowBlockScreen(context)
    }

    private val thread = HandlerThread("hsh-usage-blocker").apply { start() }
    private val handler = Handler(thread.looper)
    private val throttle = BlockScreenThrottle(RETRY_MS)

    // Touched only on [thread].
    private var foreground: ForegroundReplay.Front? = null
    private var readUntil = 0L

    private val tick = object : Runnable {
        override fun run() {
            check()?.let { handler.postDelayed(this, it) }
        }
    }

    /** Policy changes arrive on whatever thread saved them. */
    private val policyListener: () -> Unit = { resume() }

    fun start() {
        PolicyStore.addPolicyListener(policyListener)
        resume()
    }

    /** Looks at the app in front now, then keeps looking while there is something to watch. Any thread. */
    fun resume() {
        handler.removeCallbacks(tick)
        handler.post(tick)
    }

    fun shutdown() {
        PolicyStore.removePolicyListener(policyListener)
        handler.removeCallbacksAndMessages(null)
        thread.quitSafely()
    }

    /**
     * One look at the activity in front. Returns when to look again, or null
     * when there is nothing to watch until [resume].
     */
    private fun check(): Long? {
        if (!PolicyStore.hasSession(context) ||
            !UsageCollector.isScreenOn(context) ||
            !isReady(context)
        ) {
            forget()
            return null
        }
        val front = readForeground()
        val pkg = front?.packageName
        val reason = when {
            front == null -> null
            // Turning off removal protection (only while it is on: setup uses this screen to turn it on).
            ProtectedScreens.isDeviceAdminScreen(front.packageName, front.className) &&
                HshDeviceAdmin.isActive(context) -> BlockReason.ADMIN_PROTECTED
            else -> PolicyEvaluator.evaluate(context, front.packageName)
        }
        // A visit is per activity, so leaving Settings' list for the admin screen counts as new.
        val visit = front?.let { "${it.packageName}/${it.className}" }
        val action = throttle.next(visit, reason != null, SystemClock.elapsedRealtime())
        if (pkg != null && reason != null && action != BlockScreenThrottle.Action.NONE) {
            show(pkg, reason, log = action == BlockScreenThrottle.Action.SHOW_AND_LOG)
        }
        return if (pkg in ProtectedScreens.SETTINGS_PACKAGES) SETTINGS_TICK_MS else TICK_MS
    }

    private fun readForeground(): ForegroundReplay.Front? {
        val now = System.currentTimeMillis()
        foreground = if (readUntil == 0L || now < readUntil || now - readUntil > MAX_READ_GAP_MS) {
            UsageCollector.foregroundActivity(context)
        } else {
            UsageCollector.replayForeground(context, readUntil - EVENT_OVERLAP_MS, now, foreground)
        }
        readUntil = now
        return foreground
    }

    private fun forget() {
        foreground = null
        readUntil = 0L
        throttle.reset()
    }

    private fun show(pkg: String, reason: BlockReason, log: Boolean) =
        showBlockScreen(context, pkg, reason, log)
}
