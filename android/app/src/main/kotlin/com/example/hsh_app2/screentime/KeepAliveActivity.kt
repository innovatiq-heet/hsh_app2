package com.example.hsh_app2.screentime

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle

/**
 * Invisible screen that only restarts [PolicyPollService], then closes.
 *
 * [KeepAliveReceiver] opens it when Android refuses to start the service from
 * the background: Android 12+ without battery exemption, or Android 15+, where
 * "Display over other apps" alone no longer allows it. "Display over other
 * apps" still lets the receiver open an activity, and an app with an activity
 * on screen may start a foreground service.
 */
class KeepAliveActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        PolicyPollService.start(applicationContext)
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }

    companion object {
        fun intent(context: Context): Intent = Intent(context, KeepAliveActivity::class.java).addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_NO_ANIMATION or
                Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS,
        )
    }
}
