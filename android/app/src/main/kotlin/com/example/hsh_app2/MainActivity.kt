package com.example.hsh_app2

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import com.example.hsh_app2.screentime.AppBlockerAccessibilityService
import com.example.hsh_app2.screentime.DevicePolicy
import com.example.hsh_app2.screentime.PolicyPollService
import com.example.hsh_app2.screentime.PolicyStore
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
                    // ---- permissions / onboarding ----
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
                    "isBatteryOptimizationIgnored" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> result.success(requestIgnoreBatteryOptimizations())

                    // ---- monitoring lifecycle ----
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
                        PolicyPollService.stop(applicationContext)
                        ScreenTimeSync.stop(applicationContext)
                        result.success(null)
                    }
                    "syncNow" -> screenTimeExecutor.execute {
                        val status = ScreenTimeSync.syncNow(applicationContext)
                        mainHandler.post { result.success(status) }
                    }

                    // ---- policy ----
                    "syncPolicyToNative" -> {
                        val current = PolicyStore.policy(applicationContext)
                        val blocked = call.argument<List<String>>("blockedPackages")?.toSet() ?: current.blockedPackages
                        PolicyStore.savePolicy(
                            applicationContext,
                            DevicePolicy(
                                isLocked = call.argument<Boolean>("isLocked") ?: current.isLocked,
                                blockedPackages = blocked,
                                dailyLimitMinutes = call.argument<Int>("dailyLimitMinutes") ?: current.dailyLimitMinutes,
                                bedtimeStart = call.argument<String>("bedtimeStart") ?: current.bedtimeStart,
                                bedtimeEnd = call.argument<String>("bedtimeEnd") ?: current.bedtimeEnd,
                                version = call.argument<String>("version") ?: current.version,
                            ),
                        )
                        result.success(true)
                    }
                    "getPolicy" -> {
                        val p = PolicyStore.policy(applicationContext)
                        result.success(
                            mapOf(
                                "isLocked" to p.isLocked,
                                "blockedPackages" to p.blockedPackages.toList(),
                                "dailyLimitMinutes" to p.dailyLimitMinutes,
                                "bedtimeStart" to p.bedtimeStart,
                                "bedtimeEnd" to p.bedtimeEnd,
                                "version" to p.version,
                                "appliedAt" to PolicyStore.policyAppliedAt(applicationContext),
                            ),
                        )
                    }
                    "getBlockedPackages" -> result.success(PolicyStore.policy(applicationContext).blockedPackages.toList())
                    "getCompliance" -> {
                        val json = ScreenTimeSync.complianceJson(applicationContext)
                        result.success(json.keys().asSequence().associateWith { json.get(it) })
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
        runCatching {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    /** Returns false when the device offers no way to request the exemption. */
    private fun requestIgnoreBatteryOptimizations(): Boolean {
        val direct = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            .setData(Uri.parse("package:$packageName"))
        if (runCatching { startActivity(direct); true }.getOrDefault(false)) return true
        return runCatching {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            true
        }.getOrDefault(false)
    }
}
