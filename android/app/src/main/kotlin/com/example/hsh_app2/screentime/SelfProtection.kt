package com.example.hsh_app2.screentime

import android.content.Context

/**
 * Keeps a student from switching the monitor off through this app's own
 * "App info" page (Force stop / Uninstall). A force-stopped app runs nothing
 * until it is opened again, so the parent lock would silently stop.
 *
 * Only that one page is guarded. Settings as a whole stays reachable (see
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
}
