package com.example.hsh_app2.screentime

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.concurrent.Executors

/**
 * Restarts screen-time sync and the policy poller after a reboot (or an app
 * update), and immediately re-evaluates/syncs when the device clock or timezone changes.
 */
class BootPolicyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        val isTimeChange = action == Intent.ACTION_TIME_CHANGED ||
            action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == "android.intent.action.TIME_SET"
        val isBoot = action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED
        if (!isTimeChange && !isBoot) return
        if (!PolicyStore.hasSession(context)) return

        val app = context.applicationContext
        if (isTimeChange) {
            Log.w("BootPolicyReceiver", "$action — re-checking policies and syncing")
            PolicyEvaluator.invalidateUsage()
            PolicyPollService.requestRefresh(app)
            val pending = goAsync()
            EXECUTOR.execute {
                try {
                    ScreenTimeSync.syncNow(app)
                } finally {
                    pending.finish()
                }
            }
            return
        }

        Log.d("BootPolicyReceiver", "$action — restarting monitoring")
        ScreenTimeSync.schedule(app)
        PolicyPollService.start(app)
    }

    companion object {
        private val EXECUTOR = Executors.newSingleThreadExecutor()
    }
}
