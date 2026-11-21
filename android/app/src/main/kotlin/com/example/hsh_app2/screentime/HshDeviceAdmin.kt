package com.example.hsh_app2.screentime

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.concurrent.Executors

/**
 * Device admin that keeps students from removing hostel monitoring.
 *
 * While HSH is an active device admin, Android's App info page disables
 * **Force stop** and **Uninstall** for it; to remove the app the student must
 * first turn it off under Settings → Security → Device admin apps, and while a
 * student is signed in the app covers that screen ([onDisableRequested],
 * [ProtectedScreens] in [UsageAppBlocker]). It asks for
 * no admin policies (no lock, wipe or password control). It is activated in
 * student setup and removed on logout ([remove]), so an alumnus or a logged-out
 * phone can uninstall normally.
 */
class HshDeviceAdmin : DeviceAdminReceiver() {

    /**
     * Android calls this when the student taps "Deactivate", before it shows
     * the final confirmation. While signed in, cover that dialog with the block
     * screen (which then goes home), so it can't be confirmed. [UsageAppBlocker]
     * also covers the screen whenever it comes back to the front.
     */
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        if (PolicyStore.hasSession(context)) {
            Log.w(TAG, "Student tried to turn off removal protection")
            UsageAppBlocker.showBlockScreen(
                context.applicationContext, SETTINGS_PACKAGE, BlockReason.ADMIN_PROTECTED, log = true,
            )
        }
        return "Hostel monitoring stops working without this, and your warden will see the phone as unprotected."
    }

    override fun onDisabled(context: Context, intent: Intent) {
        Log.w(TAG, "Device admin turned off by the user")
        if (!PolicyStore.hasSession(context)) return
        // Report the change (compliance.deviceAdminActive) right away.
        val pending = goAsync()
        Executors.newSingleThreadExecutor().execute {
            try {
                ScreenTimeSync.syncNow(context.applicationContext)
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        private const val TAG = "HshDeviceAdmin"
        private const val SETTINGS_PACKAGE = "com.android.settings"

        fun component(context: Context) = ComponentName(context, HshDeviceAdmin::class.java)

        fun isActive(context: Context): Boolean {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager ?: return false
            return runCatching { dpm.isAdminActive(component(context)) }.getOrDefault(false)
        }

        /** The system "Activate device admin app?" screen, with our explanation. */
        fun requestIntent(context: Context): Intent =
            Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, component(context))
                .putExtra(
                    DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                    "Required by the hostel. While this is on, HSH Connect can't be force-stopped or " +
                        "uninstalled from Settings. HSH Connect uses no admin powers: it can't lock, " +
                        "erase or change passwords on your phone. It is turned off when you log out; trying to " +
                        "turn it off earlier is blocked and reported to the hostel.",
                )

        /** Logout: give up admin so the phone can uninstall the app normally. */
        fun remove(context: Context) {
            if (!isActive(context)) return
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager ?: return
            runCatching { dpm.removeActiveAdmin(component(context)) }
                .onFailure { Log.w(TAG, "removeActiveAdmin failed: ${it.message}") }
        }
    }
}
