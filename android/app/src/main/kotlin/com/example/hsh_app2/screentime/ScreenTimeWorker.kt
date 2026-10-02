package com.example.hsh_app2.screentime

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

/** Background job that syncs screen time even when the app UI is closed. */
class ScreenTimeWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    override fun doWork(): Result {
        val ctx = applicationContext
        if (!ScreenTimeSync.isConfigured(ctx)) return Result.success()

        val status = ScreenTimeSync.syncNow(ctx)
        if (status == ScreenTimeSync.STATUS_UNAUTHORIZED || status == ScreenTimeSync.STATUS_NO_SESSION) {
            return Result.success()
        }

        // Always succeed: a failed sync keeps its unsent minutes and simply
        // retries on the next tick, and a failed result would break the chain.
        when (inputData.getString(KEY_KIND)) {
            KIND_TICK -> ScreenTimeSync.scheduleNextTick(ctx)
            KIND_WATCHDOG -> ScreenTimeSync.ensureTick(ctx)
        }
        return Result.success()
    }

    companion object {
        const val KEY_KIND = "kind"
        const val KIND_TICK = "tick"
        const val KIND_WATCHDOG = "watchdog"
    }
}
