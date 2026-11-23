package com.example.hsh_app2.screentime

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The server adds every minute it receives, so the phone must never send the
 * same minutes twice. These cover the bug where a reinstall (baseline lost)
 * reported the whole day again: 2h 12m became 4h 24m.
 */
class UsageBaselineTest {
    private val minute = 60_000L

    @Test
    fun reinstallWithTheServerBaselineSendsNothingTwice() {
        // The phone measured 132 min today (2h 12m); the server already has all of it.
        val local = mapOf("com.instagram.android" to 100 * minute, "com.whatsapp" to 32 * minute)

        // Without a baseline (what a reinstall used to do) the whole day goes again.
        assertEquals(132, UsageBaseline.deltas(local, emptyMap()).values.sum())

        // Lined up with the server first: nothing new to send.
        val baseline = UsageBaseline.fromServer(
            "2026-11-24", "2026-11-24",
            mapOf("com.instagram.android" to 100, "com.whatsapp" to 32),
            curfewMinutes = 0,
        )!!
        assertTrue(UsageBaseline.deltas(local, baseline.appMillis).isEmpty())
    }

    @Test
    fun onlyTheMinutesAfterTheServersCountAreSent() {
        val baseline = UsageBaseline.fromServer("2026-11-24", "2026-11-24", mapOf("com.whatsapp" to 30), 5)!!
        val local = mapOf("com.whatsapp" to 41 * minute + 30_000L, "com.youtube" to 3 * minute)
        assertEquals(mapOf("com.whatsapp" to 11, "com.youtube" to 3), UsageBaseline.deltas(local, baseline.appMillis))
        assertEquals(5 * minute, baseline.curfewMillis)
    }

    @Test
    fun aNewStudentOnTheSamePhoneStartsFromTheirOwnCount() {
        // The previous student's baseline was large; the new student has nothing on the server.
        val baseline = UsageBaseline.fromServer("2026-11-24", "2026-11-24", emptyMap(), 0)!!
        val local = mapOf("com.whatsapp" to 20 * minute)
        assertEquals(mapOf("com.whatsapp" to 20), UsageBaseline.deltas(local, baseline.appMillis))
    }

    @Test
    fun theServerCountingMoreThanThisPhoneSendsNothingNegative() {
        val baseline = UsageBaseline.fromServer("2026-11-24", "2026-11-24", mapOf("com.whatsapp" to 90), 0)!!
        assertTrue(UsageBaseline.deltas(mapOf("com.whatsapp" to 40 * minute), baseline.appMillis).isEmpty())
    }

    @Test
    fun anotherDayOnTheServerIsNotUsed() {
        assertNull(UsageBaseline.fromServer("2026-11-23", "2026-11-24", mapOf("a.b" to 10), 0))
        // No date from the server: assume it is today.
        assertEquals(mapOf("a.b" to 10 * minute), UsageBaseline.fromServer(null, "2026-11-24", mapOf("a.b" to 10), 0)!!.appMillis)
    }

    @Test
    fun blankPackagesAndNegativeMinutesAreIgnored() {
        val b = UsageBaseline.fromServer("2026-11-24", "2026-11-24", mapOf(" " to 5, "a.b" to -3, "c.d" to 2), -1)!!
        assertEquals(mapOf("c.d" to 2 * minute), b.appMillis)
        assertEquals(0L, b.curfewMillis)
    }
}
