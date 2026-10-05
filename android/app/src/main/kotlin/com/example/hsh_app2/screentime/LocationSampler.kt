package com.example.hsh_app2.screentime

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.CancellationSignal
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * One fresh, trustworthy location fix — or null.
 *
 * Never returns a stale cached fix as if it were current, always times out,
 * and flags mock-provider locations so the evaluator can treat spoofing as a
 * violation instead of silently believing it.
 */
object LocationSampler {
    private const val TAG = "LocationSampler"
    private const val TIMEOUT_MS = 25_000L
    /** A cached fix younger than this is good enough to skip a new GPS request. */
    private const val FRESH_MS = 60_000L

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
                .filter { now - it.time <= FRESH_MS && it.accuracy <= GeofenceEvaluator.MAX_ACCURACY_M }
                .minByOrNull { it.accuracy }
            if (cached != null) return toFix(cached)

            val provider = when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && lm.isProviderEnabled(LocationManager.FUSED_PROVIDER) -> LocationManager.FUSED_PROVIDER
                lm.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
                else -> return null
            }

            val latch = CountDownLatch(1)
            val result = AtomicReference<Location?>()
            val cancel = CancellationSignal()
            LocationManagerCompat.getCurrentLocation(lm, provider, cancel, ContextCompat.getMainExecutor(context)) {
                result.set(it)
                latch.countDown()
            }
            if (!latch.await(TIMEOUT_MS, TimeUnit.MILLISECONDS)) {
                cancel.cancel()
                Log.d(TAG, "timed out waiting for $provider")
                return null
            }
            return result.get()?.let { toFix(it) }
        } catch (e: SecurityException) {
            Log.w(TAG, "permission revoked mid-sample: ${e.message}")
            return null
        } catch (e: Exception) {
            Log.w(TAG, "sample failed", e)
            return null
        }
    }

    private fun toFix(l: Location) = LocationFix(
        latitude = l.latitude,
        longitude = l.longitude,
        accuracyMeters = if (l.hasAccuracy()) l.accuracy else 999f,
        timeMillis = l.time,
        mocked = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) l.isMock else @Suppress("DEPRECATION") l.isFromMockProvider,
    )
}
