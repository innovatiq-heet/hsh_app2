package com.example.hsh_app2.screentime

import com.example.hsh_app2.screentime.BlockScreenThrottle.Action
import com.example.hsh_app2.screentime.ForegroundReplay.ACTIVITY_PAUSED
import com.example.hsh_app2.screentime.ForegroundReplay.ACTIVITY_RESUMED
import com.example.hsh_app2.screentime.ForegroundReplay.KEYGUARD_SHOWN
import com.example.hsh_app2.screentime.ForegroundReplay.SCREEN_NON_INTERACTIVE
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ForegroundTrackingTest {

    private val youtube = "com.google.android.youtube"
    private val launcher = "com.google.android.apps.nexuslauncher"
    private val hsh = "com.avd_hsh.app"

    /** Replays (type, package) events from the app [start] and returns the package in front. */
    private fun replay(start: String?, events: List<Pair<Int, String?>>): String? =
        events.fold(start?.let { ForegroundReplay.Front(it) }) { fg, (type, pkg) ->
            ForegroundReplay.step(fg, type, pkg)
        }?.packageName

    private fun front(pkg: String, cls: String) = ForegroundReplay.Front(pkg, cls)

    @Test
    fun theActivityClassIsKept() {
        val f = ForegroundReplay.step(null, ACTIVITY_RESUMED, "com.android.settings", "com.android.settings.SubSettings")
        assertEquals(front("com.android.settings", "com.android.settings.SubSettings"), f)
    }

    @Test
    fun aPauseOfAnotherActivityOfTheSameAppKeepsTheFront() {
        // Settings' list opens the device admin screen: the new one may resume before the old one pauses.
        val list = "com.android.settings.SubSettings"
        val admin = "com.android.settings.applications.specialaccess.deviceadmin.DeviceAdminAdd"
        var f = ForegroundReplay.step(front("com.android.settings", list), ACTIVITY_RESUMED, "com.android.settings", admin)
        f = ForegroundReplay.step(f, ACTIVITY_PAUSED, "com.android.settings", list)
        assertEquals(front("com.android.settings", admin), f)
        assertNull(ForegroundReplay.step(f, ACTIVITY_PAUSED, "com.android.settings", admin))
    }

    @Test
    fun theDeviceAdminScreenIsRecognised() {
        val aosp = "com.android.settings.applications.specialaccess.deviceadmin.DeviceAdminAdd"
        assertTrue(ProtectedScreens.isDeviceAdminScreen("com.android.settings", aosp))
        assertTrue(ProtectedScreens.isDeviceAdminScreen("com.android.settings", "com.android.settings.DeviceAdminAdd"))
        assertTrue(ProtectedScreens.isDeviceAdminScreen("com.samsung.android.settings", "com.samsung.Foo\$DeviceAdminAdd"))
    }

    @Test
    fun otherSettingsScreensAndOtherAppsAreLeftAlone() {
        assertFalse(ProtectedScreens.isDeviceAdminScreen("com.android.settings", "com.android.settings.SubSettings"))
        assertFalse(ProtectedScreens.isDeviceAdminScreen("com.android.settings", "com.android.settings.DeviceAdminSettings"))
        assertFalse(ProtectedScreens.isDeviceAdminScreen("com.android.settings", null))
        assertFalse(ProtectedScreens.isDeviceAdminScreen("com.example.other", "com.example.other.DeviceAdminAdd"))
    }

    @Test
    fun theLastResumedAppIsInFront() {
        val events = listOf(
            ACTIVITY_PAUSED to launcher,
            ACTIVITY_RESUMED to youtube,
        )
        assertEquals(youtube, replay(launcher, events))
    }

    @Test
    fun theBlockScreenTakesOverTheFront() {
        val events = listOf(
            ACTIVITY_PAUSED to youtube,
            ACTIVITY_RESUMED to hsh,
        )
        assertEquals(hsh, replay(youtube, events))
    }

    @Test
    fun aPauseOfAnotherAppKeepsTheFront() {
        // Android may report the new app resumed before the old one paused.
        val events = listOf(
            ACTIVITY_RESUMED to youtube,
            ACTIVITY_PAUSED to launcher,
        )
        assertEquals(youtube, replay(launcher, events))
    }

    @Test
    fun screenOffOrLockScreenMeansNothingIsInFront() {
        assertNull(replay(youtube, listOf(SCREEN_NON_INTERACTIVE to null)))
        assertNull(replay(youtube, listOf(KEYGUARD_SHOWN to null)))
    }

    @Test
    fun anAppThatPausedWithoutAReplacementIsNotTreatedAsInFront() {
        // Fail open: when unsure which app is in front, block nothing.
        assertNull(replay(youtube, listOf(ACTIVITY_PAUSED to youtube)))
    }

    @Test
    fun replayingEventsAlreadyAppliedGivesTheSameFront() {
        // UsageAppBlocker re-reads the last few seconds on every look, starting
        // from what it found last time. That must match reading everything once.
        val opened = listOf(
            ACTIVITY_PAUSED to launcher,
            ACTIVITY_RESUMED to youtube,
            ACTIVITY_PAUSED to youtube,
            ACTIVITY_RESUMED to hsh,
            ACTIVITY_PAUSED to hsh,
            ACTIVITY_RESUMED to launcher,
            ACTIVITY_PAUSED to launcher,
            ACTIVITY_RESUMED to youtube,
        )
        val sequences = listOf(
            opened,
            opened + (ACTIVITY_PAUSED to youtube),
            opened + (SCREEN_NON_INTERACTIVE to null),
            opened + (ACTIVITY_PAUSED to launcher),
        )
        for ((n, events) in sequences.withIndex()) {
            val expected = replay(launcher, events)
            for (split in 0..events.size) {
                val first = replay(launcher, events.take(split))
                for (overlap in 0..split) {
                    val again = replay(first, events.drop(split - overlap))
                    assertEquals("sequence=$n split=$split overlap=$overlap", expected, again)
                }
            }
        }
        assertEquals(youtube, replay(launcher, sequences[0]))
        assertNull(replay(launcher, sequences[1]))
        assertNull(replay(launcher, sequences[2]))
        assertEquals(youtube, replay(launcher, sequences[3]))
    }

    @Test
    fun aBlockIsShownAndLoggedOncePerVisit() {
        val throttle = BlockScreenThrottle(retryMs = 2_000L)
        assertEquals(Action.SHOW_AND_LOG, throttle.next(youtube, blocked = true, nowMs = 0L))
        assertEquals(Action.NONE, throttle.next(youtube, blocked = true, nowMs = 1_000L))
        // Still in front: the block screen did not open, so try again without a new log entry.
        assertEquals(Action.SHOW, throttle.next(youtube, blocked = true, nowMs = 2_000L))
        assertEquals(Action.NONE, throttle.next(youtube, blocked = true, nowMs = 3_000L))
        assertEquals(Action.SHOW, throttle.next(youtube, blocked = true, nowMs = 4_000L))
    }

    @Test
    fun reopeningARestrictedAppIsANewVisit() {
        val throttle = BlockScreenThrottle(retryMs = 2_000L)
        assertEquals(Action.SHOW_AND_LOG, throttle.next(youtube, blocked = true, nowMs = 0L))
        assertEquals(Action.NONE, throttle.next(hsh, blocked = false, nowMs = 500L))
        assertEquals(Action.SHOW_AND_LOG, throttle.next(youtube, blocked = true, nowMs = 1_000L))
    }

    @Test
    fun anAppRestrictedWhileInUseIsBlockedAtOnce() {
        val throttle = BlockScreenThrottle(retryMs = 2_000L)
        assertEquals(Action.NONE, throttle.next(youtube, blocked = false, nowMs = 0L))
        assertEquals(Action.SHOW_AND_LOG, throttle.next(youtube, blocked = true, nowMs = 1_000L))
    }

    @Test
    fun nothingIsShownForAnUnknownOrAllowedApp() {
        val throttle = BlockScreenThrottle(retryMs = 2_000L)
        assertEquals(Action.NONE, throttle.next(null, blocked = true, nowMs = 0L))
        assertEquals(Action.NONE, throttle.next(launcher, blocked = false, nowMs = 1_000L))
    }

    @Test
    fun resetStartsANewVisit() {
        val throttle = BlockScreenThrottle(retryMs = 2_000L)
        assertEquals(Action.SHOW_AND_LOG, throttle.next(youtube, blocked = true, nowMs = 0L))
        throttle.reset() // screen turned off
        assertEquals(Action.SHOW_AND_LOG, throttle.next(youtube, blocked = true, nowMs = 500L))
    }
}
