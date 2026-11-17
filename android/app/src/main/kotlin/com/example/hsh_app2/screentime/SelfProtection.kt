package com.example.hsh_app2.screentime

import android.content.Context

/**
 * Keeps a student from switching the monitor off through this app's own
 * "App info" page (Force stop / Uninstall) or the notification shade's
 * Active apps panel (Stop). A stopped app enforces nothing, so the parent lock
 * would silently stop.
 *
 * Only those two places are guarded. Settings as a whole stays reachable (see
 * [PolicyEvaluator]'s protected packages), and the Accessibility page — needed
 * during setup — never shows a Force-stop button, so it is not matched.
 *
 * The matcher is pure (strings in, boolean out) so it runs in plain JVM tests.
 */
object SelfProtection {
    /** Packages that host the system "App info" screen. */
    val SETTINGS_PACKAGES = setOf(
        "com.android.settings",
        "com.samsung.android.settings",
        "com.miui.securitycenter",
    )

    private const val DEFAULT_GRACE_MS = 2 * 60 * 1000L

    /** Used when the Settings app's own wording can't be looked up. */
    private val FALLBACK_LABELS = listOf("force stop", "uninstall")

    @Volatile private var graceUntil = 0L

    /**
     * The app itself is about to open its own App info page (e.g. to grant
     * "Allow all the time" location), so let it through for a short while.
     */
    fun allowAppSettings(durationMs: Long = DEFAULT_GRACE_MS) {
        graceUntil = System.currentTimeMillis() + durationMs
    }

    fun inGrace(now: Long = System.currentTimeMillis()): Boolean = now < graceUntil

    /**
     * True when [texts] (everything visible on a Settings screen) show this
     * app's name next to a Force stop / Uninstall control.
     */
    fun isOwnAppDetailsPage(
        texts: Collection<String>,
        appLabel: String,
        dangerLabels: Collection<String>,
    ): Boolean {
        val label = appLabel.trim().lowercase()
        if (label.isEmpty()) return false
        val shown = texts.mapTo(HashSet()) { it.trim().lowercase() }
        if (label !in shown) return false
        return dangerLabels.any { d -> d.isNotBlank() && d.trim().lowercase() in shown }
    }

    /** "Force stop" / "Uninstall" as the device's Settings app words them, plus English. */
    fun dangerLabels(context: Context): List<String> {
        val labels = ArrayList(FALLBACK_LABELS)
        for (pkg in SETTINGS_PACKAGES) {
            runCatching {
                val res = context.packageManager.getResourcesForApplication(pkg)
                for (name in listOf("force_stop", "uninstall_text")) {
                    val id = res.getIdentifier(name, "string", pkg)
                    if (id != 0) labels.add(res.getString(id))
                }
            }
        }
        return labels
    }

    // ---------- Active apps panel (Android 13+ notification shade) ----------
    //
    // The shade's "N apps are active" button opens a list of apps running a
    // foreground service, each with a Stop button ("Active apps" on Pixel,
    // "Enabled apps" on OnePlus/Oppo). Stop kills the whole app: the poller,
    // the blocker and the location pings. Android shows that button for every
    // ordinary app, so the accessibility service closes the panel whenever it
    // offers to stop *this* app. Other apps' rows and the rest of the shade are
    // left alone.

    /** Packages that draw the notification shade and its Active apps panel. */
    val SYSTEM_UI_PACKAGES = setOf("com.android.systemui")

    /** SystemUI's string for the per-app Stop button (AOSP name). */
    private const val SYSTEM_UI_STOP_LABEL = "fgs_manager_app_item_stop_button_label"
    private const val FALLBACK_STOP_LABEL = "stop"

    /**
     * How far above a Stop button to look for the app's name. The panel puts
     * them in one row (button → row, or button → wrapper → row). A notification's
     * action buttons sit 3+ levels away from its header, so another app's
     * "Stop" notification action never pairs up with our notification's name.
     */
    private const val ROW_DEPTH = 3

    /** A snapshot of one on-screen node: its text / content description and children. */
    class ScreenNode(val texts: List<String>, val children: List<ScreenNode> = emptyList())

    /**
     * True when [root] (one SystemUI window) shows a Stop control in the same
     * row as [appLabel], i.e. the Active apps panel offering to stop this app.
     */
    fun offersToStopOwnApp(root: ScreenNode, appLabel: String, stopLabels: Collection<String>): Boolean {
        val label = normalize(appLabel)
        if (label.isEmpty()) return false
        val stops = stopLabels.mapNotNullTo(HashSet()) { normalize(it).ifEmpty { null } }
        if (stops.isEmpty()) return false

        val path = ArrayList<ScreenNode>()
        fun visit(node: ScreenNode): Boolean {
            if (node.texts.any { normalize(it) in stops }) {
                val row = path.getOrNull(path.size - ROW_DEPTH) ?: path.firstOrNull() ?: node
                if (containsText(row, label)) return true
            }
            path.add(node)
            val found = node.children.any { visit(it) }
            path.removeAt(path.lastIndex)
            return found
        }
        return visit(root)
    }

    private fun containsText(node: ScreenNode, normalized: String): Boolean =
        node.texts.any { normalize(it) == normalized } || node.children.any { containsText(it, normalized) }

    private fun normalize(s: String) = s.trim().lowercase()

    @Volatile private var stopLabelsCache: Pair<java.util.Locale, List<String>>? = null

    /** The panel's "Stop" as the device's SystemUI words it, plus English. Cached per locale. */
    fun stopLabels(context: Context): List<String> {
        val locale = java.util.Locale.getDefault()
        stopLabelsCache?.let { (cachedFor, labels) -> if (cachedFor == locale) return labels }
        val labels = arrayListOf(FALLBACK_STOP_LABEL)
        for (pkg in SYSTEM_UI_PACKAGES) {
            runCatching {
                val res = context.packageManager.getResourcesForApplication(pkg)
                val id = res.getIdentifier(SYSTEM_UI_STOP_LABEL, "string", pkg)
                if (id != 0) labels.add(res.getString(id))
            }
        }
        stopLabelsCache = locale to labels
        return labels
    }
}
