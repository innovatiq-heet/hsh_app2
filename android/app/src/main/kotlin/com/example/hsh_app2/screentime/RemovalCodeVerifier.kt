package com.example.hsh_app2.screentime

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * Checks a warden-issued one-time 6-digit code against the hostel server, so a student can turn
 * off removal protection ([HshDeviceAdmin]) themselves for a genuine uninstall or phone handover,
 * without a warden needing to be physically present at the phone.
 *
 * The code itself is never generated or stored on the phone: a warden requests it from the
 * student's screen in the app (`ParentalControlsCard.generateRemovalCode`, `POST
 * /screen-time/removal-codes`), and this only ever asks the server "is this code valid for the
 * signed-in student, right now". See docs/PARENT_CONTROL_DOCS.md §5.7.
 */
object RemovalCodeVerifier {
    private const val TAG = "RemovalCodeVerifier"

    /**
     * [onResult] (always called on a background thread) gets true only when the server confirms
     * [code] as valid for the signed-in student. Any error — no session, no network, a non-2xx
     * response, a malformed body — is false, never true: a failure must never accidentally grant
     * removal.
     */
    fun verify(context: Context, code: String, onResult: (Boolean) -> Unit) {
        val token = PolicyStore.token(context)
        val baseUrl = PolicyStore.baseUrl(context)
        if (token.isNullOrEmpty() || baseUrl.isNullOrEmpty()) {
            onResult(false)
            return
        }

        thread(name = "RemovalCodeVerifyThread") {
            var valid = false
            try {
                val url = URL("$baseUrl/screen-time/removal-codes/verify")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 10_000
                    readTimeout = 10_000
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("Accept", "application/json")
                    setRequestProperty("Authorization", "Bearer $token")
                }
                val body = JSONObject().apply { put("code", code) }
                conn.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }

                val status = conn.responseCode
                if (status in 200..299) {
                    val text = conn.inputStream.bufferedReader().use { it.readText() }
                    valid = runCatching { JSONObject(text).optBoolean("valid", false) }.getOrDefault(false)
                }
                Log.i(TAG, "Removal code check: http=$status valid=$valid")
            } catch (e: Exception) {
                Log.w(TAG, "Removal code verify failed", e)
            } finally {
                onResult(valid)
            }
        }
    }
}
