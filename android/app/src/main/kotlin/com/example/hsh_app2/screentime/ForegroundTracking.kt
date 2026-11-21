package com.example.hsh_app2.screentime

/**
 * Which app is in front, rebuilt from Android usage events one event at a
 * time. Pure (event type and package in, package out) so it runs in plain JVM
 * tests; [UsageCollector] reads the events.
 */
object ForegroundReplay {
    // UsageEvents.Event constants (literal values so they work below the API
    // level that introduced the named constants).
    const val ACTIVITY_RESUMED = 1
    const val ACTIVITY_PAUSED = 2
    const val SCREEN_NON_INTERACTIVE = 16
    const val KEYGUARD_SHOWN = 17
    const val DEVICE_SHUTDOWN = 26

    /** The activity in front: its app and, when Android reports it, its class. */
    data class Front(val packageName: String, val className: String? = null)

    /** The activity in front after one event, given the one in front before it (null = none). */
    fun step(front: Front?, eventType: Int, packageName: String?, className: String? = null): Front? =
        when (eventType) {
            ACTIVITY_RESUMED -> packageName?.let { Front(it, className) }
            // A pause of another activity (even of the same app) leaves the front alone.
            ACTIVITY_PAUSED -> if (front != null && front.packageName == packageName &&
                (className == null || front.className == null || front.className == className)
            ) {
                null
            } else {
                front
            }
            SCREEN_NON_INTERACTIVE, KEYGUARD_SHOWN, DEVICE_SHUTDOWN -> null
            else -> front
        }
}

/**
 * Settings screens that would remove the app's protection. Pure so it runs in
 * plain JVM tests.
 */
object ProtectedScreens {
    val SETTINGS_PACKAGES = setOf(
        "com.android.settings",
        "com.samsung.android.settings",
        "com.miui.securitycenter",
    )

    /**
     * Whether [packageName]/[className] is Settings' device admin
     * activate / deactivate screen (`DeviceAdminAdd`, also opened by
     * "Uninstall" on the App info page of an active admin). The device admin
     * *list* is left alone, and so is every other Settings screen.
     */
    fun isDeviceAdminScreen(packageName: String?, className: String?): Boolean =
        packageName in SETTINGS_PACKAGES &&
            className != null &&
            className.substringAfterLast('.').substringAfterLast('$') == "DeviceAdminAdd"
}

/**
 * For [UsageAppBlocker], which looks at the app in front once a second:
 * decides whether to open the block screen and whether to log a block event.
 *
 * A block is logged once per visit (each time the restricted app comes to
 * the front). While the
 * restricted app stays in front, which means the block screen did not open,
 * the screen is opened again every [retryMs] without logging again.
 */
class BlockScreenThrottle(private val retryMs: Long) {
    enum class Action { NONE, SHOW, SHOW_AND_LOG }

    private var visit: String? = null
    private var logged = false
    private var shownAt = 0L

    /**
     * [foreground] is the app in front (null when unknown), [blocked] whether
     * the policy forbids it, [nowMs] a monotonic clock.
     */
    fun next(foreground: String?, blocked: Boolean, nowMs: Long): Action {
        if (foreground != visit) {
            visit = foreground
            logged = false
        }
        if (foreground == null || !blocked) {
            logged = false
            return Action.NONE
        }
        if (!logged) {
            logged = true
            shownAt = nowMs
            return Action.SHOW_AND_LOG
        }
        if (nowMs - shownAt < retryMs) return Action.NONE
        shownAt = nowMs
        return Action.SHOW
    }

    fun reset() {
        visit = null
        logged = false
    }
}
