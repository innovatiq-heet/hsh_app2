package com.example.hsh_app2

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import com.example.hsh_app2.callerid.CallerIdOverlay
import com.example.hsh_app2.callerid.CallerIdStore
import com.example.hsh_app2.screentime.AppBlockerAccessibilityService
import com.example.hsh_app2.screentime.DevicePolicy
import com.example.hsh_app2.screentime.GeofenceEvaluator
import com.example.hsh_app2.screentime.LocationSampler
import com.example.hsh_app2.screentime.PolicyPollService
import com.example.hsh_app2.screentime.PolicyStore
import com.example.hsh_app2.screentime.ScreenTimeSync
import com.example.hsh_app2.screentime.UsageCollector
import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val screenTimeExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Pending answer for the Call Screening role dialog. */
    private var roleResult: MethodChannel.Result? = null
    /** Set when launched from a caller-ID popup/notification; read once by Flutter. */
    private var launchTarget: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureLaunchTarget(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        captureLaunchTarget(intent)
    }

    private fun captureLaunchTarget(intent: Intent?) {
        val target = intent?.getStringExtra(CallerIdOverlay.EXTRA_TARGET) ?: return
        launchTarget = mapOf(
            "target" to target,
            "studentId" to (intent.getStringExtra(CallerIdOverlay.EXTRA_STUDENT_ID) ?: ""),
            "query" to (intent.getStringExtra(CallerIdOverlay.EXTRA_QUERY) ?: ""),
        )
        intent.removeExtra(CallerIdOverlay.EXTRA_TARGET)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_CALL_SCREENING_ROLE) {
            val held = holdsScreeningRole()
            if (held) CallerIdStore.setActive(this, true)
            roleResult?.success(held)
            roleResult = null
        }
    }

    private fun holdsScreeningRole(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val rm = getSystemService(Context.ROLE_SERVICE) as RoleManager
        return rm.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) && rm.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
    }

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hsh/caller_id")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStatus" -> result.success(
                        mapOf(
                            "supported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q),
                            "enabled" to holdsScreeningRole(),
                            "overlayGranted" to CallerIdOverlay.canDraw(this),
                            "active" to CallerIdStore.isActive(this),
                        ),
                    )
                    // System sheet: "Set HSH App as your caller ID & spam app?"
                    "requestEnable" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            result.success(false)
                        } else if (holdsScreeningRole()) {
                            CallerIdStore.setActive(this, true)
                            result.success(true)
                        } else {
                            roleResult?.success(false)
                            roleResult = result
                            val rm = getSystemService(Context.ROLE_SERVICE) as RoleManager
                            startActivityForResult(rm.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING), REQ_CALL_SCREENING_ROLE)
                        }
                    }
                    "requestOverlay" -> {
                        if (CallerIdOverlay.canDraw(this)) {
                            result.success(true)
                        } else {
                            runCatching {
                                startActivity(
                                    Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")),
                                )
                            }
                            result.success(false)
                        }
                    }
                    "setActive" -> {
                        val active = call.argument<Boolean>("active") ?: false
                        CallerIdStore.setActive(this, active)
                        if (!active) CallerIdOverlay.hide()
                        result.success(null)
                    }
                    "consumeLaunchTarget" -> {
                        result.success(launchTarget)
                        launchTarget = null
                    }
                    // Warden can test the lookup from the app without a real call.
                    "lookup" -> {
                        val matches = CallerIdStore.lookup(this, call.argument<String>("number"))
                        result.success(matches.map { mapOf("studentId" to it.studentId, "name" to it.name, "place" to it.place, "relation" to it.relation) })
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hsh/geofence")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStatus" -> result.success(jsonToMap(GeofenceEvaluator.statusJson(applicationContext)))
                    "locationPermission" -> result.success(LocationSampler.permission(applicationContext).name.lowercase())
                    // Forces one fix + evaluation now (student just finished setup, or a warden is testing).
                    "sampleNow" -> screenTimeExecutor.execute {
                        val fix = LocationSampler.sample(applicationContext)
                        val event = fix?.let { GeofenceEvaluator.process(applicationContext, it) }
                        if (event != null) ScreenTimeSync.syncNow(applicationContext)
                        val status = jsonToMap(GeofenceEvaluator.statusJson(applicationContext))
                        mainHandler.post { result.success(status) }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** org.json → Flutter-codec-friendly maps/lists. */
    private fun jsonToMap(json: JSONObject): Map<String, Any?> =
        json.keys().asSequence().associateWith { k -> jsonValue(json.get(k)) }

    private fun jsonValue(v: Any?): Any? = when (v) {
        null, JSONObject.NULL -> null
        is JSONObject -> jsonToMap(v)
        is JSONArray -> (0 until v.length()).map { jsonValue(v.get(it)) }
        else -> v
    }

    companion object {
        private const val REQ_CALL_SCREENING_ROLE = 7201
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
