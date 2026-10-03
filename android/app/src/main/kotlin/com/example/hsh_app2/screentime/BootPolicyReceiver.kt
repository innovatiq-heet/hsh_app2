package com.example.hsh_app2.screentime

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Restarts screen-time sync and the policy poller after a reboot (or an app
 * update) so remote lock enforcement survives power cycles.
 */
class BootPolicyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> Unit
            else -> return
        }
        if (!PolicyStore.hasSession(context)) return
        Log.d("BootPolicyReceiver", "${intent.action} — restarting monitoring")
        ScreenTimeSync.schedule(context)
        PolicyPollService.start(context)
    }
}
