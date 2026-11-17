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

    // ---------- Active apps panel ----------

    private val stop = listOf("Stop")

    private fun node(vararg texts: String, children: List<SelfProtection.ScreenNode> = emptyList()) =
        SelfProtection.ScreenNode(texts.toList(), children)

    /** One panel row as AOSP lays it out: icon, (name, duration), Stop button. */
    private fun panelRow(app: String, stopText: String = "Stop") = node(
        children = listOf(
            node(),
            node(children = listOf(node(app), node("2 hr"))),
            node(stopText),
        ),
    )

    private fun panel(vararg rows: SelfProtection.ScreenNode) = node(
        children = listOf(
            node("Enabled apps"),
            node("Apps are kept active when you're not using them."),
            node(children = rows.toList()),
        ),
    )

    @Test
    fun activeAppsPanelListingThisAppIsGuarded() {
        val screen = panel(panelRow(label), panelRow("YouTube"), panelRow("HariPrabodham Vrund"))
        assertTrue(SelfProtection.offersToStopOwnApp(screen, label, stop))
    }

    @Test
    fun stopButtonWrappedInAContainerStillPairsWithItsRow() {
        val row = node(
            children = listOf(
                node(children = listOf(node(children = listOf(node(label))))),
                node(children = listOf(node("Stop"))),
            ),
        )
        assertTrue(SelfProtection.offersToStopOwnApp(panel(row), label, stop))
    }

    @Test
    fun activeAppsPanelWithoutThisAppIsLeftAlone() {
        val screen = panel(panelRow("YouTube"), panelRow("Spotify"))
        assertFalse(SelfProtection.offersToStopOwnApp(screen, label, stop))
    }

    @Test
    fun shadeWithOurNotificationAndAnotherAppsStopActionIsLeftAlone() {
        // Our monitoring notification (no actions) next to a timer notification with a Stop action.
        fun notification(app: String, title: String, actions: List<String>) = node(
            children = listOf(
                node(
                    children = listOf(
                        node(children = listOf(node(app), node("now"))),
                        node(children = listOf(node(title))),
                        node(
                            children = listOf(
                                node(children = listOf(node(children = actions.map { node(it) }))),
                            ),
                        ),
                    ),
                ),
            ),
        )
        val shade = node(
            children = listOf(
                node(children = listOf(node("9:34"), node("Mon, Nov 16"))),
                node(
                    children = listOf(
                        notification(label, "Hostel monitoring active", emptyList()),
                        notification("Clock", "Timer", listOf("Stop", "+1 min")),
                    ),
                ),
                node("3 apps are active"),
            ),
        )
        assertFalse(SelfProtection.offersToStopOwnApp(shade, label, stop))
    }

    @Test
    fun localizedStopLabelFromSystemUiIsMatched() {
        val screen = panel(panelRow(label, stopText = "रोकें"))
        assertFalse(SelfProtection.offersToStopOwnApp(screen, label, stop))
        assertTrue(SelfProtection.offersToStopOwnApp(screen, label, listOf("Stop", "रोकें")))
    }

    @Test
    fun panelMatchingIgnoresCaseAndSpaces() {
        val screen = panel(panelRow("  hsh seva ", stopText = "STOP "))
        assertTrue(SelfProtection.offersToStopOwnApp(screen, label, stop))
    }

    @Test
    fun stopMatchingNeedsALabelAndAStopWord() {
        val screen = panel(panelRow(label))
        assertFalse(SelfProtection.offersToStopOwnApp(screen, "", stop))
        assertFalse(SelfProtection.offersToStopOwnApp(screen, label, listOf(" ")))
    }

    @Test
    fun graceLetsOwnPermissionFlowThroughThenExpires() {
        SelfProtection.allowAppSettings(durationMs = 1_000L)
        val now = System.currentTimeMillis()
        assertTrue(SelfProtection.inGrace(now))
        assertFalse(SelfProtection.inGrace(now + 5_000L))
    }
}
