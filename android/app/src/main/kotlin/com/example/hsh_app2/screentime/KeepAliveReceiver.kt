package com.example.hsh_app2.screentime

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log

/**
 * Brings monitoring back about 5–10 s after the student taps **Stop** in the
 * Android 13+ Active apps panel (notification shade, "N apps are active").
 *
 * Stop kills the whole process: the poller, the app blocker and curfew
 * location. Android offers no way for an ordinary app to hide that button.
 * Unlike Force stop, Stop keeps the app's alarms and jobs, so this alarm still
 * fires and restarts [PolicyPollService].
 *
 * [PolicyPollService] keeps pushing the alarm back (every 2 s with the screen
 * on), so it never fires while the service is alive. Android 12+ lets the receiver start a
 * foreground service from the background only when battery optimization is
 * off for the app (setup step 4). When Android refuses, the receiver opens
 * [KeepAliveActivity] (needs "Display over other apps"), which starts it from
 * the foreground. Failing both, [ScreenTimeWorker] restarts it later.
 */
class KeepAliveReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        if (!PolicyStore.hasSession(context)) return // logged out: let the chain end
        if (!PolicyPollService.isRunning()) {
            Log.w(TAG, "Monitoring was stopped; restarting it")
            restartMonitoring(context)
            ScreenTimeSync.ensureTick(context)
        }
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        schedule(context, pm.isInteractive)
    }

    companion object {
        private const val TAG = "KeepAliveReceiver"
        private const val REQUEST_CODE = 7301

        /**
         * Screen on (the only time Stop can be tapped): about the shortest delay
         * Android allows an alarm. [PolicyPollService] re-arms it every
         * [RE_ARM_SCREEN_ON_MS], so it fires about 5–9 s after the process dies.
         * Not a wakeup alarm, so it costs nothing once the phone sleeps.
         */
        private const val SCREEN_ON_DELAY_MS = 5_000L
        const val RE_ARM_SCREEN_ON_MS = 2_000L

        /** Screen off: longer than the service's longest tick (60 s), so a live service re-arms it first. */
        private const val SCREEN_OFF_DELAY_MS = 75_000L

        /** Arms (or pushes back) the alarm. Inexact, so it needs no exact-alarm permission. */
        fun schedule(context: Context, screenOn: Boolean) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val pi = pendingIntent(context)
            runCatching {
                if (screenOn) {
                    am.set(AlarmManager.ELAPSED_REALTIME, SystemClock.elapsedRealtime() + SCREEN_ON_DELAY_MS, pi)
                } else {
                    val at = SystemClock.elapsedRealtime() + SCREEN_OFF_DELAY_MS
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, at, pi)
                    } else {
                        am.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, at, pi)
                    }
                }
            }.onFailure { Log.w(TAG, "schedule failed: ${it.message}") }
        }

        /**
         * Starts [PolicyPollService] from the background; if Android refuses,
         * from [KeepAliveActivity] (needs "Display over other apps").
         */
        fun restartMonitoring(context: Context) {
            if (PolicyPollService.start(context) || !PolicyStore.hasSession(context)) return
            if (!UsageAppBlocker.canShowBlockScreen(context)) return
            Log.w(TAG, "Background start refused; restarting from KeepAliveActivity")
            runCatching { context.startActivity(KeepAliveActivity.intent(context)) }
                .onFailure { Log.e(TAG, "KeepAliveActivity failed to launch: ${it.message}") }
        }

        fun cancel(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            runCatching { am.cancel(pendingIntent(context)) }
        }

        private fun pendingIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            Intent(context, KeepAliveReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
