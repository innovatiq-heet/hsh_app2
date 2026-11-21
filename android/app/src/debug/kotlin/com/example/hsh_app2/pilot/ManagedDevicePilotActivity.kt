package com.example.hsh_app2.pilot

import android.app.Activity
import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.os.Build
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class ManagedDevicePilotAdmin : DeviceAdminReceiver()

/** Local controls for a spare test phone, launched from an authorized ADB shell. */
class ManagedDevicePilotActivity : Activity() {
    private val policy by lazy { requireNotNull(getSystemService(DevicePolicyManager::class.java)) }
    private val admin by lazy { ComponentName(this, ManagedDevicePilotAdmin::class.java) }
    private lateinit var status: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val padding = (24 * resources.displayMetrics.density).toInt()
            setPadding(padding, padding, padding, padding)
        }
        status = TextView(this).apply { textSize = 18f }
        panel.addView(status)
        setContentView(panel)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            status.text = "The pilot requires Android 7 or later."
            return
        }
        if (!policy.isDeviceOwnerApp(packageName)) {
            status.text = "Enroll this debug build as device owner first."
            return
        }

        refreshStatus()
        panel.addButton("Block YouTube") { setYouTubeSuspended(true) }
        panel.addButton("Restore YouTube") { setYouTubeSuspended(false) }
        panel.addButton("Lock screen now") { runPolicyAction { policy.lockNow() } }
    }

    private fun setYouTubeSuspended(suspended: Boolean) = runPolicyAction {
        val rejected = policy.setPackagesSuspended(admin, arrayOf(YOUTUBE), suspended)
        check(rejected.isEmpty()) { "Android rejected the change. Check that YouTube is installed." }
        refreshStatus()
    }

    private fun refreshStatus() {
        val state = runCatching { policy.isPackageSuspended(admin, YOUTUBE) }
            .fold(
                onSuccess = { if (it) "Blocked" else "Available" },
                onFailure = { "Unavailable (${it.message})" },
            )
        status.text = "HSH managed-device pilot\nYouTube: $state"
    }

    private fun runPolicyAction(action: () -> Unit) {
        runCatching(action).onFailure { status.text = "Policy update failed: ${it.message}" }
    }

    private fun LinearLayout.addButton(label: String, action: () -> Unit) {
        addView(Button(context).apply {
            text = label
            setOnClickListener { action() }
        })
    }

    private companion object {
        const val YOUTUBE = "com.google.android.youtube"
    }
}
