package com.example.hsh_app2

import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import com.example.hsh_app2.screentime.AppBlockerAccessibilityService
import com.example.hsh_app2.screentime.PolicyPollService
import com.example.hsh_app2.screentime.ScreenTimeSync
import com.example.hsh_app2.screentime.UsageCollector
import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import androidx.core.content.ContextCompat
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
                    "hasAccessibilityPermission" -> result.success(AppBlockerAccessibilityService.isEnabled(this))
                    "openAccessibilitySettings" -> {
                        openAccessibilitySettings()
                        result.success(null)
                    }
                    "startMonitoring" -> {
                        val token = call.argument<String>("token")
                        val baseUrl = call.argument<String>("baseUrl")
                        if (token.isNullOrEmpty() || baseUrl.isNullOrEmpty()) {
                            result.error("bad_args", "token and baseUrl are required", null)
                        } else {
                            ScreenTimeSync.start(applicationContext, token, baseUrl)
                            PolicyPollService.start(applicationContext)
                            result.success(null)
                        }
                    }
                    "stopMonitoring" -> {
                        ScreenTimeSync.stop(applicationContext)
                        PolicyPollService.stop(applicationContext)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hsh/geofence_location")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasLocationPermission" -> {
                        val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                        val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                        result.success(fine || coarse)
                    }
                    "getCurrentLocation" -> {
                        val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                        val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                        if (!fine && !coarse) {
                            result.error("permission_denied", "Location permission not granted", null)
                            return@setMethodCallHandler
                        }

                        val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                        if (lm == null) {
                            result.error("no_location_manager", "Location service not available", null)
                            return@setMethodCallHandler
                        }

                        var bestLoc: Location? = null
                        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)
                        for (provider in providers) {
                            try {
                                if (lm.isProviderEnabled(provider)) {
                                    val loc = lm.getLastKnownLocation(provider)
                                    if (loc != null) {
                                        if (bestLoc == null || loc.accuracy < bestLoc.accuracy || loc.time > bestLoc.time) {
                                            bestLoc = loc
                                        }
                                    }
                                }
                            } catch (_: SecurityException) {}
                        }

                        if (bestLoc != null) {
                            result.success(mapOf(
                                "latitude" to bestLoc.latitude,
                                "longitude" to bestLoc.longitude,
                                "accuracy" to bestLoc.accuracy.toDouble(),
                                "time" to bestLoc.time
                            ))
                        } else {
                            try {
                                val provider = if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                                    LocationManager.NETWORK_PROVIDER
                                } else if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                                    LocationManager.GPS_PROVIDER
                                } else null

                                if (provider != null) {
                                    lm.requestSingleUpdate(provider, object : LocationListener {
                                        override fun onLocationChanged(location: Location) {
                                            result.success(mapOf(
                                                "latitude" to location.latitude,
                                                "longitude" to location.longitude,
                                                "accuracy" to location.accuracy.toDouble(),
                                                "time" to location.time
                                            ))
                                        }
                                        @Deprecated("Deprecated in Java")
                                        override fun onStatusChanged(p: String?, s: Int, e: Bundle?) {}
                                        override fun onProviderEnabled(p: String) {}
                                        override fun onProviderDisabled(p: String) {}
                                    }, Looper.getMainLooper())
                                } else {
                                    result.error("no_provider", "Location providers disabled", null)
                                }
                            } catch (e: Exception) {
                                result.error("location_error", e.message, null)
                            }
                        }
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

    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        try {
            startActivity(intent)
        } catch (_: Exception) {
            // Fallback
        }
    }
}
