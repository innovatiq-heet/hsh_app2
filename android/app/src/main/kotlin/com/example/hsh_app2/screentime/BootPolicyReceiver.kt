package com.example.hsh_app2.screentime

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Restarts the PolicyPollService and WorkManager screen-time sync after
 * device reboot, ensuring remote lock enforcement survives power cycles.
 */
class BootPolicyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        Log.d("BootPolicyReceiver", "Boot completed — restarting policy sync")

        // Resume the WorkManager screen-time sync chain
        if (ScreenTimeSync.isConfigured(context)) {
            ScreenTimeSync.schedule(context)
        }

        // Restart the rapid policy poller
        PolicyPollService.start(context)
    }
}
