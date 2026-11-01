package com.example.hsh_app2.screentime

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SelfProtectionTest {
    private val label = "HSH Seva"
    private val danger = listOf("Force stop", "Uninstall")

    @Test
    fun ownAppInfoPageWithForceStopIsGuarded() {
        val page = listOf("App info", "HSH Seva", "Open", "Uninstall", "Force stop", "Notifications")
        assertTrue(SelfProtection.isOwnAppDetailsPage(page, label, danger))
    }

    @Test
    fun matchingIgnoresCaseAndSpaces() {
        val page = listOf("  hsh seva ", "FORCE STOP")
        assertTrue(SelfProtection.isOwnAppDetailsPage(page, label, danger))
    }

    @Test
    fun anotherAppsInfoPageIsNotGuarded() {
        val page = listOf("App info", "WhatsApp", "Uninstall", "Force stop")
        assertFalse(SelfProtection.isOwnAppDetailsPage(page, label, danger))
    }

    @Test
    fun accessibilityPageForThisAppIsNotGuarded() {
        // Setup needs this page; it shows the app name but no Force stop button.
        val page = listOf("Accessibility", "HSH Seva", "Use HSH Seva", "On")
        assertFalse(SelfProtection.isOwnAppDetailsPage(page, label, danger))
    }

    @Test
    fun blankLabelNeverMatches() {
        assertFalse(SelfProtection.isOwnAppDetailsPage(listOf("", "Force stop"), "", danger))
    }

    @Test
    fun graceLetsOwnPermissionFlowThroughThenExpires() {
        SelfProtection.allowAppSettings(durationMs = 1_000L)
        val now = System.currentTimeMillis()
        assertTrue(SelfProtection.inGrace(now))
        assertFalse(SelfProtection.inGrace(now + 5_000L))
    }
}
