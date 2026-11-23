package com.example.hsh_app2.screentime

import org.json.JSONArray
import org.json.JSONObject

/**
 * One curfew window from `policy.curfew_sessions` (a warden session or the
 * student's personal bedtime). Same maths as the backend
 * (`screentime.sessions.ts`) and `lib/features/screentime/curfew/curfew_schedule.dart`:
 *
 * - Times are IST wall-clock minutes, whatever the phone's time zone.
 * - A window whose end is before its start crosses midnight and belongs to the
 *   day it **starts**: a Monday-only 22:00–06:00 runs Mon 22:00 → Tue 06:00.
 * - [days] holds indexes 0 = Monday … 6 = Sunday.
 */
data class CurfewWindow(
    val startMinutes: Int,
    val endMinutes: Int,
    val days: Set<Int>,
    val name: String = "",
) {
    val crossesMidnight: Boolean get() = endMinutes < startMinutes

    private fun hasDay(weekday: Int) = ((weekday % 7) + 7) % 7 in days

    /** Whether the window covers [nowMillis]. */
    fun isRunning(nowMillis: Long): Boolean {
        if (startMinutes == endMinutes) return false
        val (weekday, m) = CurfewSchedule.istDayAndMinute(nowMillis)
        return if (startMinutes < endMinutes) {
            hasDay(weekday) && m >= startMinutes && m < endMinutes
        } else {
            (hasDay(weekday) && m >= startMinutes) || (hasDay(weekday - 1) && m < endMinutes)
        }
    }

    /**
     * Every run of this window that overlaps [from, to), as epoch-ms
     * intervals clipped to the range.
     */
    fun runsBetween(from: Long, to: Long): List<LongRange> {
        if (to <= from || startMinutes == endMinutes) return emptyList()
        val out = ArrayList<LongRange>()
        // Start one IST day early so a run that began yesterday evening counts.
        var dayStart = CurfewSchedule.istMidnight(from) - CurfewSchedule.DAY_MS
        while (dayStart < to) {
            val weekday = CurfewSchedule.istDayAndMinute(dayStart).first
            if (hasDay(weekday)) {
                val runStart = dayStart + startMinutes * CurfewSchedule.MINUTE_MS
                val runEnd = dayStart + endMinutes * CurfewSchedule.MINUTE_MS +
                    (if (crossesMidnight) CurfewSchedule.DAY_MS else 0L)
                val s = maxOf(runStart, from)
                val e = minOf(runEnd, to)
                if (e > s) out.add(s until e)
            }
            dayStart += CurfewSchedule.DAY_MS
        }
        return out
    }

    fun toJson(): JSONObject = JSONObject()
        .put("start", startMinutes)
        .put("end", endMinutes)
        .put("days", JSONArray(days.sorted()))
        .put("name", name)
}

object CurfewSchedule {
    const val MINUTE_MS = 60_000L
    const val DAY_MS = 24 * 60 * MINUTE_MS

    /** IST is UTC+05:30 all year (no daylight saving). */
    const val IST_OFFSET_MS = (5 * 60 + 30) * MINUTE_MS

    val DAY_KEYS = listOf("mon", "tue", "wed", "thu", "fri", "sat", "sun")

    /** (weekday 0 = Monday … 6 = Sunday, minute of the IST day). */
    fun istDayAndMinute(millis: Long): Pair<Int, Int> {
        val ist = millis + IST_OFFSET_MS
        val days = Math.floorDiv(ist, DAY_MS)
        val minute = (Math.floorMod(ist, DAY_MS) / MINUTE_MS).toInt()
        // 1970-01-01 was a Thursday (index 3).
        val weekday = Math.floorMod(days + 3, 7L).toInt()
        return weekday to minute
    }

    /** Epoch ms of the IST midnight that starts the IST day containing [millis]. */
    fun istMidnight(millis: Long): Long =
        Math.floorDiv(millis + IST_OFFSET_MS, DAY_MS) * DAY_MS - IST_OFFSET_MS

    fun parseMinutes(hhmm: String?): Int? {
        val parts = hhmm?.trim()?.split(":") ?: return null
        if (parts.size < 2) return null
        val h = parts[0].toIntOrNull() ?: return null
        val m = parts[1].take(2).toIntOrNull() ?: return null
        if (h !in 0..23 || m !in 0..59) return null
        return h * 60 + m
    }

    /**
     * Parses the backend's `curfew_sessions` array
     * (`start_time`, `end_time`, `days: ["mon", …]`, `name`). Entries with bad
     * times are skipped.
     */
    fun fromBackend(arr: JSONArray): List<CurfewWindow> = (0 until arr.length()).mapNotNull { i ->
        val o = arr.optJSONObject(i) ?: return@mapNotNull null
        val start = parseMinutes(o.optString("start_time", o.optString("startTime")))
            ?: return@mapNotNull null
        val end = parseMinutes(o.optString("end_time", o.optString("endTime")))
            ?: return@mapNotNull null
        val daysArr = o.optJSONArray("days")
        val days = if (daysArr == null) {
            DAY_KEYS.indices.toSet()
        } else {
            (0 until daysArr.length())
                .mapNotNull { DAY_KEYS.indexOf(daysArr.optString(it).trim().lowercase()).takeIf { d -> d >= 0 } }
                .toSet()
        }
        CurfewWindow(start, end, days, o.optString("name", ""))
    }

    /** Reads what [toStorage] wrote; null when nothing was stored. */
    fun fromStorage(raw: String?): List<CurfewWindow>? {
        if (raw.isNullOrEmpty()) return null
        return runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                val d = o.getJSONArray("days")
                CurfewWindow(
                    o.getInt("start"),
                    o.getInt("end"),
                    (0 until d.length()).map { d.getInt(it) }.toSet(),
                    o.optString("name", ""),
                )
            }
        }.getOrNull()
    }

    fun toStorage(windows: List<CurfewWindow>): String = JSONArray(windows.map { it.toJson() }).toString()

    /** Block while **any** window is running. */
    fun isInCurfew(windows: List<CurfewWindow>, nowMillis: Long): Boolean = windows.any { it.isRunning(nowMillis) }

    /** The union of every window's runs inside [from, to), merged so overlaps count once. */
    fun curfewIntervals(windows: List<CurfewWindow>, from: Long, to: Long): List<LongRange> {
        val runs = windows.flatMap { it.runsBetween(from, to) }.sortedBy { it.first }
        val merged = ArrayList<LongRange>()
        for (r in runs) {
            val last = merged.lastOrNull()
            if (last != null && r.first <= last.last + 1) {
                merged[merged.size - 1] = last.first..maxOf(last.last, r.last)
            } else {
                merged.add(r)
            }
        }
        return merged
    }
}
