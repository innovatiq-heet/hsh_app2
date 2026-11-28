package com.example.hsh_app2.screentime

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * Catches newly installed apps on student devices.
 * Automatically quarantines (blocks) the app and notifies the backend / warden for approval.
 */
class PackageInstallReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PackageInstallReceiver"

        fun requestAppApprovalSync(
            context: Context,
            packageName: String,
            appName: String,
            reason: String? = null,
        ): Boolean {
            val token = PolicyStore.token(context)
            val baseUrl = PolicyStore.baseUrl(context)
            if (token.isNullOrEmpty() || baseUrl.isNullOrEmpty()) return false

            return try {
                val url = URL("$baseUrl/screen-time/apps/request")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 10_000
                    readTimeout = 10_000
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("Accept", "application/json")
                    setRequestProperty("Authorization", "Bearer $token")
                }
                val body = JSONObject().apply {
                    put("package_name", packageName)
                    put("app_name", appName)
                    if (!reason.isNullOrBlank()) put("reason", reason.trim())
                }
                conn.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
                val code = conn.responseCode
                Log.i(TAG, "Submitted approval request for $packageName ($appName): code $code")
                val ok = code in 200..299
                if (ok) PolicyStore.removePendingQuarantine(context, packageName)
                ok
            } catch (e: Exception) {
                Log.w(TAG, "Failed to submit approval request for $packageName", e)
                false
            }
        }

        fun requestAppApproval(
            context: Context,
            packageName: String,
            appName: String,
            reason: String? = null,
            onDone: ((Boolean) -> Unit)? = null
        ) {
            thread(name = "AppApprovalRequestThread") {
                val success = requestAppApprovalSync(context, packageName, appName, reason)
                onDone?.invoke(success)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null || intent.action != Intent.ACTION_PACKAGE_ADDED) return

        // Uri format is: package:com.example.app
        val uri = intent.data ?: return
        val packageName = uri.schemeSpecificPart ?: return

        // Skip protected packages (e.g. system, dialer, settings, own app)
        if (PolicyEvaluator.isProtected(context, packageName) || packageName == context.packageName) {
            return
        }

        val pm = context.packageManager
        val appName = try {
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            packageName
        }

        Log.i(TAG, "New app installed: $packageName ($appName). Quarantining and requesting warden approval.")

        // 1. Persist in durable offline quarantine queue + immediately block locally
        PolicyStore.addPendingQuarantine(context, packageName, appName)
        PolicyStore.addBlockedPackage(context, packageName)

        // 2. Transmit request to hostel administration (clears pending queue on 2xx)
        requestAppApproval(context, packageName, appName)
    }
}
