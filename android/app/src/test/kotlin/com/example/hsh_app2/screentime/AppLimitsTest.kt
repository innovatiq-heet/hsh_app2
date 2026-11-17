package com.example.hsh_app2.screentime

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AppLimitsTest {

    @Test
    fun rulesWithALimitBecomeLimits() {
        val limits = AppLimits.fromRules(
            listOf(
                "com.instagram.android" to 45,
                "com.whatsapp" to 0, // a rule without a limit (e.g. only blocked)
                "com.google.android.youtube" to null,
                "  " to 30, // no package
                " com.snapchat.android " to 20,
            ),
        )
        assertEquals(mapOf("com.instagram.android" to 45, "com.snapchat.android" to 20), limits)
    }

    @Test
    fun aLimitAboveADayIsCappedAtADay() {
        assertEquals(mapOf("a.b" to 1440), AppLimits.fromRules(listOf("a.b" to 5000)))
    }

    @Test
    fun anAppIsStoppedOnceItsOwnTimeIsUsedUp() {
        val limits = mapOf("com.instagram.android" to 45)
        assertFalse(AppLimits.reached(limits, "com.instagram.android", 44))
        assertTrue(AppLimits.reached(limits, "com.instagram.android", 45))
        assertTrue(AppLimits.reached(limits, "com.instagram.android", 90))
    }

    @Test
    fun appsWithoutALimitAreNeverStoppedByIt() {
        val limits = mapOf("com.instagram.android" to 45)
        assertFalse(AppLimits.reached(limits, "com.whatsapp", 600))
        assertFalse(AppLimits.reached(emptyMap(), "com.instagram.android", 600))
    }
}
