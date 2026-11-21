package com.example.hsh_app2.screentime

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.provider.Settings
import android.util.Log

/**
 * App blocker for phones where [AppBlockerAccessibilityService] is not
 * running. Some UPI and banking apps refuse to work while a third-party
 * accessibility service is on, so a student may keep it off.
 *
 * While the screen is on, this reads Android usage events every [TICK_MS] to
 * find the app in front, and opens [BlockedAppActivity] over it when
 * [PolicyEvaluator] forbids it. It uses the same rules, block screen and block
 * events as the accessibility service.
 *
 * Needs Usage access to see the app in front and, on Android 10+, "Display
 * over other apps": without it Android does not let a background app open an
 * activity. It stands down while the accessibility service is connected, so a
 * block is never shown or logged twice. Self-protection (App info page,
 * Active apps panel) needs the accessibility service and is not done here.
 *
 * Owned by [PolicyPollService]. It stops looking while the screen is off, the
 * accessibility service is connected or a permission is missing; [resume]
 * (screen on, service tick, policy change, accessibility service stopped)
 * starts it again.
 */
class UsageAppBlocker(private val context: Context) {

    companion object {
        private const val TAG = "UsageAppBlocker"
        private const val TICK_MS = 1_000L
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

        /** Whether this blocker can enforce the policy while the accessibility service is off. */
        fun isReady(context: Context): Boolean =
            UsageCollector.hasPermission(context) && canShowBlockScreen(context)
    }

    private val thread = HandlerThread("hsh-usage-blocker").apply { start() }
    private val handler = Handler(thread.looper)
    private val throttle = BlockScreenThrottle(RETRY_MS)

    // Touched only on [thread].
    private var foreground: String? = null
    private var readUntil = 0L

    private val tick = object : Runnable {
        override fun run() {
            if (check()) handler.postDelayed(this, TICK_MS)
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

    /** One look at the app in front. False when there is nothing to watch until [resume]. */
    private fun check(): Boolean {
        if (!PolicyStore.hasSession(context) ||
            !UsageCollector.isScreenOn(context) ||
            AppBlockerAccessibilityService.isConnected() ||
            !isReady(context)
        ) {
            forget()
            return false
        }
        val pkg = readForeground()
        val reason = pkg?.let { PolicyEvaluator.evaluate(context, it) }
        val action = throttle.next(pkg, reason != null, SystemClock.elapsedRealtime())
        if (pkg != null && reason != null && action != BlockScreenThrottle.Action.NONE) {
            show(pkg, reason, log = action == BlockScreenThrottle.Action.SHOW_AND_LOG)
        }
        return true
    }

    private fun readForeground(): String? {
        val now = System.currentTimeMillis()
        foreground = if (readUntil == 0L || now < readUntil || now - readUntil > MAX_READ_GAP_MS) {
            UsageCollector.foregroundPackage(context)
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

    private fun show(pkg: String, reason: BlockReason, log: Boolean) {
        val appName = UsageCollector.appLabel(context, pkg)
        if (log) {
            Log.w(TAG, "Blocking $pkg (${reason.wireName})")
            PolicyStore.recordBlockEvent(context, pkg, appName, reason)
        }
        runCatching { context.startActivity(BlockedAppActivity.intent(context, pkg, appName, reason)) }
            .onFailure { Log.e(TAG, "BlockedAppActivity failed to launch: ${it.message}") }
    }
}
