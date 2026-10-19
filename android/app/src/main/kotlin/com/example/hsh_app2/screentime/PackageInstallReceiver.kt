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

        fun requestAppApproval(context: Context, packageName: String, appName: String, onDone: ((Boolean) -> Unit)? = null) {
            val token = PolicyStore.token(context)
            val baseUrl = PolicyStore.baseUrl(context)
            if (token.isNullOrEmpty() || baseUrl.isNullOrEmpty()) {
                onDone?.invoke(false)
                return
            }

            thread(name = "AppApprovalRequestThread") {
                var success = false
                try {
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

                    val body = JSONObject()
                        .put("package_name", packageName)
                        .put("app_name", appName)

                    conn.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
                    val code = conn.responseCode
                    Log.i(TAG, "Submitted approval request for $packageName ($appName): code $code")
                    success = code in 200..299
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to submit approval request for $packageName", e)
                } finally {
                    onDone?.invoke(success)
                }
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

        // 1. Instantly quarantine / auto-block locally
        PolicyStore.addBlockedPackage(context, packageName)

        // 2. Transmit request to hostel administration
        requestAppApproval(context, packageName, appName)
    }
}
