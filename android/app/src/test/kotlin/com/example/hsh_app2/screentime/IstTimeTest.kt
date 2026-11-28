package com.example.hsh_app2.screentime

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.util.Calendar
import java.util.TimeZone

/** Verifies native screentime / geofence / usage date checks stay on IST even on non-IST devices. */
class IstTimeTest {

    private val ist = ZoneOffset.ofHoursMinutes(5, 30)
    private lateinit var previousTz: TimeZone

    private fun atIst(y: Int, mo: Int, d: Int, h: Int, mi: Int): Long =
        LocalDateTime.of(y, mo, d, h, mi).toInstant(ist).toEpochMilli()

    private fun localCal(millis: Long): Calendar = Calendar.getInstance().apply { timeInMillis = millis }

    @Before
    fun switchDeviceToNewYork() {
        previousTz = TimeZone.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone("America/New_York"))
    }

    @After
    fun restoreTimeZone() {
        TimeZone.setDefault(previousTz)
    }

    @Test
    fun `geofence isInCurfew uses IST regardless of device timezone`() {
        // 2026-11-23 is a Monday in IST (still afternoon in New York for 22:00 IST).
        val monNight = GeofencePolicy(
            active = true,
            start = "22:00",
            end = "06:00",
            repeatDays = listOf("Mon"),
        )
        assertFalse(GeofenceEvaluator.isInCurfew(monNight, localCal(atIst(2026, 11, 23, 21, 59))))
        assertTrue(GeofenceEvaluator.isInCurfew(monNight, localCal(atIst(2026, 11, 23, 22, 0))))
        assertTrue(GeofenceEvaluator.isInCurfew(monNight, localCal(atIst(2026, 11, 24, 5, 59))))
        assertFalse(GeofenceEvaluator.isInCurfew(monNight, localCal(atIst(2026, 11, 24, 6, 0))))
        assertFalse(GeofenceEvaluator.isInCurfew(monNight, localCal(atIst(2026, 11, 24, 23, 0))))
    }

    @Test
    fun `usage startOfDay and sync date string use IST midnight and date`() {
        // 2026-11-24 00:30 IST = 2026-11-23 14:00 EST (previous calendar day in New York).
        val istTueEarly = atIst(2026, 11, 24, 0, 30)
        val expectedIstMidnight = atIst(2026, 11, 24, 0, 0)

        val dayStart = UsageCollector.startOfDay(istTueEarly)
        assertEquals(expectedIstMidnight, dayStart)
        assertEquals(atIst(2026, 11, 25, 0, 0), UsageCollector.nextDayStart(dayStart))
        assertEquals("2026-11-24", ScreenTimeSync.istDateString(dayStart))
        assertEquals("2026-11-24", ScreenTimeSync.istDateString(istTueEarly))
    }
}
