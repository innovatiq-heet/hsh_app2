package com.example.hsh_app2.screentime

/**
 * What the server already counts for today, as the phone's "already sent"
 * baseline. `POST /screen-time/ping` **adds** the minutes it receives, so the
 * phone sends only the difference from this baseline.
 *
 * The baseline normally lives on the phone, but a reinstall (or clearing the
 * app's data) loses it, and a new login may be a different student. The phone
 * then re-reads the server's numbers (`GET /screen-time/live`) and uses them,
 * instead of reporting the whole day again on top of what the server has
 * (which doubled the day: 2h 12m became 4h 24m).
 */
object UsageBaseline {
    private const val MINUTE_MS = 60_000L

    data class Baseline(val appMillis: Map<String, Long>, val curfewMillis: Long)

    /**
     * Baseline for [today] from the server's own numbers, or null when the
     * server's day is another day (its `date` is IST; a phone whose clock or
     * time zone disagrees can't be lined up and keeps its own baseline).
     */
    fun fromServer(
        serverDate: String?,
        today: String,
        appMinutes: Map<String, Int>,
        curfewMinutes: Int,
    ): Baseline? {
        if (!serverDate.isNullOrBlank() && serverDate != today) return null
        val apps = LinkedHashMap<String, Long>()
        for ((pkg, minutes) in appMinutes) {
            val name = pkg.trim()
            if (name.isEmpty() || minutes <= 0) continue
            apps[name] = (apps[name] ?: 0L) + minutes * MINUTE_MS
        }
        return Baseline(apps, curfewMinutes.coerceAtLeast(0) * MINUTE_MS)
    }

    /**
     * Whole new minutes per app since [sent]. An app the server already counts
     * more of than this phone measured (another device, or a ping whose reply
     * was lost) sends nothing rather than a negative number.
     */
    fun deltas(local: Map<String, Long>, sent: Map<String, Long>): LinkedHashMap<String, Int> {
        val out = LinkedHashMap<String, Int>()
        for ((pkg, millis) in local) {
            val delta = ((millis - (sent[pkg] ?: 0L)) / MINUTE_MS).toInt()
            if (delta > 0) out[pkg] = delta
        }
        return out
    }
}
