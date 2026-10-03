package com.example.hsh_app2.callerid

import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import androidx.annotation.RequiresApi

/**
 * Runs the instant a call arrives (before the phone rings) while this app
 * holds the Call Screening role. We only *identify* — every call is allowed
 * through — and we must answer within a few seconds, so the lookup is a
 * single indexed SQLite query.
 */
@RequiresApi(Build.VERSION_CODES.Q)
class CallerIdScreeningService : CallScreeningService() {

    override fun onScreenCall(details: Call.Details) {
        // Always let the call proceed; identification is a side effect.
        respondToCall(details, CallResponse.Builder().build())

        if (!CallerIdStore.isActive(this)) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            details.callDirection != Call.Details.DIRECTION_INCOMING
        ) return

        val number = details.handle?.schemeSpecificPart ?: return
        val matches = CallerIdStore.lookup(this, number)
        if (matches.isEmpty()) {
            Log.d(TAG, "no phonebook match for incoming call")
            return
        }
        Log.i(TAG, "incoming call matched ${matches.size} record(s)")
        CallerIdNotifier.notifyIncoming(this, number, matches)
        CallerIdOverlay.show(applicationContext, number, matches)
    }

    companion object {
        private const val TAG = "CallerIdScreening"
    }
}
