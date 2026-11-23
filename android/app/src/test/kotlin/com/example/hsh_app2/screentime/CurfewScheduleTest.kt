package com.example.hsh_app2.screentime

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneOffset

/** Same cases as the backend e2e test and the Dart curfew_schedule_test (2026-11-23 is a Monday). */
class CurfewScheduleTest {

    private val ist = ZoneOffset.ofHoursMinutes(5, 30)
    private fun at(y: Int, mo: Int, d: Int, h: Int, mi: Int): Long =
        LocalDateTime.of(y, mo, d, h, mi).toInstant(ist).toEpochMilli()

    private val everyDay = (0..6).toSet()
    private val monOnlyNight = CurfewWindow(22 * 60, 6 * 60, setOf(0))
    private val study = CurfewWindow(14 * 60, 16 * 60, everyDay)

    @Test
    fun `IST weekday and minute`() {
        assertEquals(0 to 22 * 60, CurfewSchedule.istDayAndMinute(at(2026, 11, 23, 22, 0)))
        assertEquals(6 to 0, CurfewSchedule.istDayAndMinute(at(2026, 11, 29, 0, 0)))
    }

    @Test
    fun `an overnight window belongs to the day it starts on`() {
        assertFalse(monOnlyNight.isRunning(at(2026, 11, 23, 21, 59)))
        assertTrue(monOnlyNight.isRunning(at(2026, 11, 23, 22, 0)))
        assertTrue(monOnlyNight.isRunning(at(2026, 11, 24, 5, 59)))
        assertFalse(monOnlyNight.isRunning(at(2026, 11, 24, 6, 0)))
        assertFalse(monOnlyNight.isRunning(at(2026, 11, 24, 23, 0)))
        assertFalse(monOnlyNight.isRunning(at(2026, 11, 23, 3, 0)))
    }

    @Test
    fun `same-day window`() {
        assertFalse(study.isRunning(at(2026, 11, 25, 13, 59)))
        assertTrue(study.isRunning(at(2026, 11, 25, 15, 0)))
        assertFalse(study.isRunning(at(2026, 11, 25, 16, 0)))
    }

    @Test
    fun `blocks while any session runs`() {
        val night = CurfewWindow(22 * 60, 6 * 60, everyDay)
        val monStudy = CurfewWindow(14 * 60, 16 * 60, setOf(0))
        val set = listOf(night, monStudy)
        assertTrue(CurfewSchedule.isInCurfew(set, at(2026, 11, 23, 15, 0)))
        assertFalse(CurfewSchedule.isInCurfew(set, at(2026, 11, 24, 15, 0)))
        assertTrue(CurfewSchedule.isInCurfew(set, at(2026, 11, 24, 23, 0)))
        assertFalse(CurfewSchedule.isInCurfew(emptyList(), at(2026, 11, 24, 23, 0)))
    }

    @Test
    fun `curfew runs inside one IST day, overlaps merged`() {
        val night = CurfewWindow(22 * 60, 6 * 60, everyDay)
        val late = CurfewWindow(23 * 60, 23 * 60 + 30, everyDay)
        val dayStart = at(2026, 11, 24, 0, 0)
        val runs = CurfewSchedule.curfewIntervals(listOf(night, late, study), dayStart, at(2026, 11, 25, 0, 0))
        val minutes = runs.map { (it.last + 1 - it.first) / 60_000L }
        // 00:00–06:00 (yesterday's night run), 14:00–16:00, 22:00–24:00 (late merged in).
        assertEquals(listOf(360L, 120L, 120L), minutes)
        assertEquals(dayStart, runs.first().first)
    }

    @Test
    fun `legacy bedtime applies every day when the server sends no sessions`() {
        val legacy = DevicePolicy(bedtimeStart = "23:00:00", bedtimeEnd = "05:00:00")
        assertTrue(legacy.hasCurfew)
        assertTrue(CurfewSchedule.isInCurfew(legacy.effectiveCurfews, at(2026, 11, 24, 1, 0)))
        // An empty session list from a new server means no curfew, even with an old bedtime.
        val none = legacy.copy(curfews = emptyList())
        assertFalse(none.hasCurfew)
    }
}
