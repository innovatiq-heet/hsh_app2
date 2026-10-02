package com.example.hsh_app2

import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import com.example.hsh_app2.screentime.ScreenTimeSync
import com.example.hsh_app2.screentime.UsageCollector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val screenTimeExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hsh/screen_time")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsagePermission" -> result.success(UsageCollector.hasPermission(this))
                    "openUsageSettings" -> {
                        openUsageSettings()
                        result.success(null)
                    }
                    "startMonitoring" -> {
                        val token = call.argument<String>("token")
                        val baseUrl = call.argument<String>("baseUrl")
                        if (token.isNullOrEmpty() || baseUrl.isNullOrEmpty()) {
                            result.error("bad_args", "token and baseUrl are required", null)
                        } else {
                            ScreenTimeSync.start(applicationContext, token, baseUrl)
                            result.success(null)
                        }
                    }
                    "stopMonitoring" -> {
                        ScreenTimeSync.stop(applicationContext)
                        result.success(null)
                    }
                    "syncNow" -> screenTimeExecutor.execute {
                        val status = ScreenTimeSync.syncNow(applicationContext)
                        mainHandler.post { result.success(status) }
                    }
                    "syncPolicyToNative" -> {
                        val blockedPackages = call.argument<List<String>>("blockedPackages") ?: emptyList()
                        val isLocked = call.argument<Boolean>("isLocked") ?: false
                        val prefs = applicationContext.getSharedPreferences("hsh_screen_time_policy", android.content.Context.MODE_PRIVATE)
                        prefs.edit().apply {
                            putStringSet("blocked_packages", blockedPackages.toSet())
                            putBoolean("is_locked", isLocked)
                            apply()
                        }
                        result.success(true)
                    }
                    "getBlockedPackages" -> {
                        val prefs = applicationContext.getSharedPreferences("hsh_screen_time_policy", android.content.Context.MODE_PRIVATE)
                        val set = prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()
                        result.success(set.toList())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Usage access can't be requested via a runtime dialog — only via Settings. */
    private fun openUsageSettings() {
        val direct = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            .setData(Uri.fromParts("package", packageName, null))
        try {
            startActivity(direct)
        } catch (_: Exception) {
            // Many ROMs don't support the per-app deep link; fall back to the list.
            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        }
    }
}
