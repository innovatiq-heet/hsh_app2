package com.example.hsh_app2.screentime

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.CancellationSignal
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.gms.tasks.Tasks
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * One fresh, trustworthy location fix — or null.
 *
 * Prefers Play Services' fused provider (GPS+Wi-Fi+cell, noticeably better
 * indoors) when it's on the device, and falls back to plain
 * [LocationManager] when it isn't — a de-Googled phone or custom ROM still
 * gets a fix, just a possibly coarser one. Never returns a stale cached fix
 * as if it were current, always times out, and flags mock-provider locations
 * so the evaluator can treat spoofing as a violation instead of silently
 * believing it.
 */
object LocationSampler {
    private const val TAG = "LocationSampler"
    private const val TIMEOUT_MS = 25_000L
    /** A cached fix younger than this is good enough to skip a new GPS request. */
    private const val FRESH_MS = 60_000L
    /**
     * Total time allowed to look for a better live fix before settling for
     * whatever's best so far. A single `getCurrentLocation` call often
     * returns the first (coarse, network-based) fix it sees rather than
     * waiting for GPS to lock, especially indoors — sampling a few times
     * within this budget and keeping the best one fixes that without a new
     * dependency.
     */
    private const val SAMPLE_BUDGET_MS = 10_000L
    /** Stop sampling early once a fix is at least this good. */
    private const val GOOD_ENOUGH_ACCURACY_M = 20f
    private const val MAX_SAMPLES = 3

    enum class Permission { DENIED, FOREGROUND, ALWAYS }

    fun permission(context: Context): Permission {
        val fine = granted(context, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = granted(context, Manifest.permission.ACCESS_COARSE_LOCATION)
        if (!fine && !coarse) return Permission.DENIED
        val background = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            granted(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        return if (background) Permission.ALWAYS else Permission.FOREGROUND
    }

    fun hasAnyPermission(context: Context) = permission(context) != Permission.DENIED

    /** Whether the system location switch is on. */
    fun isLocationEnabled(context: Context): Boolean {
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
        return LocationManagerCompat.isLocationEnabled(lm)
    }

    private fun granted(context: Context, perm: String) =
        ContextCompat.checkSelfPermission(context, perm) == PackageManager.PERMISSION_GRANTED

    /** Blocking; call off the main thread. */
    fun sample(context: Context): LocationFix? {
        if (!hasAnyPermission(context)) return null
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        if (!LocationManagerCompat.isLocationEnabled(lm)) {
            Log.d(TAG, "location services off")
            return null
        }

        val now = System.currentTimeMillis()
        try {
            // Reuse a very recent accurate fix rather than waking the GPS again.
            val cached = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
                .mapNotNull { runCatching { lm.getLastKnownLocation(it) }.getOrNull() }
                .filter {
                val pm = context.getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
                val freshWindow = if (pm?.isInteractive == true) FRESH_MS else 3 * 60_000L
                now - it.time <= freshWindow && it.accuracy <= GeofenceEvaluator.MAX_ACCURACY_M
            }
                .minByOrNull { it.accuracy }
            if (cached != null) return toFix(cached)

            val provider = when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && lm.isProviderEnabled(LocationManager.FUSED_PROVIDER) -> LocationManager.FUSED_PROVIDER
                lm.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
                else -> return null
            }

            var fused = fusedClientIfAvailable(context)
            val budgetDeadline = System.currentTimeMillis() + SAMPLE_BUDGET_MS
            var best: Location? = null
            for (attempt in 1..MAX_SAMPLES) {
                val remaining = budgetDeadline - System.currentTimeMillis()
                if (attempt > 1 && remaining <= 0) break
                val timeout = minOf(TIMEOUT_MS, remaining.coerceAtLeast(1_000L))

                val client = fused
                val fix = if (client != null) {
                    requestOneFused(client, timeout) ?: run {
                        // Play Services misbehaved mid-loop (e.g. died): don't
                        // keep paying its timeout on later attempts.
                        fused = null
                        requestOne(lm, context, provider, timeout)
                    }
                } else {
                    requestOne(lm, context, provider, timeout)
                }
                if (fix == null) break // provider/permission failure — a retry won't help
                if (isMocked(fix)) return toFix(fix) // don't dilute a spoofing signal by averaging it away

                if (best == null || fix.accuracy < best!!.accuracy) best = fix
                if (best!!.accuracy <= GOOD_ENOUGH_ACCURACY_M) break
            }
            return best?.let { toFix(it) }
        } catch (e: SecurityException) {
            Log.w(TAG, "permission revoked mid-sample: ${e.message}")
            return null
        } catch (e: Exception) {
            Log.w(TAG, "sample failed", e)
            return null
        }
    }

    /** Play Services' fused client, or null if it's not on this device. */
    private fun fusedClientIfAvailable(context: Context): FusedLocationProviderClient? = try {
        if (GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(context) == ConnectionResult.SUCCESS) {
            LocationServices.getFusedLocationProviderClient(context)
        } else {
            null
        }
    } catch (e: Exception) {
        Log.d(TAG, "Play Services unavailable: ${e.message}")
        null
    }

    /** One blocking fused-provider request, capped at [timeoutMs]. */
    @SuppressLint("MissingPermission") // checked by the caller via hasAnyPermission()
    private fun requestOneFused(client: FusedLocationProviderClient, timeoutMs: Long): Location? {
        val cancel = CancellationTokenSource()
        return try {
            Tasks.await(client.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, cancel.token), timeoutMs, TimeUnit.MILLISECONDS)
        } catch (e: Exception) {
            Log.d(TAG, "fused request failed: ${e.message}")
            null
        } finally {
            cancel.cancel()
        }
    }

    /** One blocking `getCurrentLocation` call, capped at [timeoutMs]. */
    private fun requestOne(lm: LocationManager, context: Context, provider: String, timeoutMs: Long): Location? {
        val latch = CountDownLatch(1)
        val result = AtomicReference<Location?>()
        val cancel = CancellationSignal()
        LocationManagerCompat.getCurrentLocation(lm, provider, cancel, ContextCompat.getMainExecutor(context)) {
            result.set(it)
            latch.countDown()
        }
        if (!latch.await(timeoutMs, TimeUnit.MILLISECONDS)) {
            cancel.cancel()
            Log.d(TAG, "timed out waiting for $provider")
            return null
        }
        return result.get()
    }

    private fun isMocked(l: Location): Boolean {
        val isMock = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            l.isMock
        } else {
            @Suppress("DEPRECATION") l.isFromMockProvider
        }
        // Heuristic: zero accuracy is a signature of artificial GPS injection.
        return isMock || (l.hasAccuracy() && l.accuracy == 0f)
    }

    private fun toFix(l: Location) = LocationFix(
        latitude = l.latitude,
        longitude = l.longitude,
        accuracyMeters = if (l.hasAccuracy()) l.accuracy else 999f,
        timeMillis = l.time,
        mocked = isMocked(l),
    )
}
