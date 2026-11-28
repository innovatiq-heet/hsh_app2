package com.example.hsh_app2.screentime

import android.app.role.RoleManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.inputmethod.InputMethodManager

/** Why an app was stopped — surfaced on the block screen and in the audit log. */
enum class BlockReason(val wireName: String, val tag: String, val title: String, val message: String) {
    DEVICE_LOCKED(
        "device_locked", "DEVICE REMOTELY LOCKED", "Phone Locked",
        "Your device has been remotely locked by hostel administration.",
    ),
    APP_BLOCKED(
        "app_blocked", "HOSTEL POLICY ENFORCEMENT", "App Restricted",
        "This app has been restricted by hostel policy.",
    ),
    INSTALLER_BLOCKED(
        "installer_blocked", "APP INSTALLATION RESTRICTED", "Installation Blocked",
        "Downloading or installing apps from Play Store or APK files is restricted by hostel administration. Please request approval from your Warden.",
    ),
    BEDTIME(
        "bedtime", "CURFEW HOURS", "Curfew Active",
        "Phone use is not allowed during hostel curfew hours.",
    ),
    DAILY_LIMIT(
        "daily_limit", "DAILY LIMIT REACHED", "Screen Time Over",
        "You have used up today's screen-time allowance.",
    ),
    APP_LIMIT(
        "app_limit", "APP TIME LIMIT REACHED", "App Time Over",
        "You have used up today's time for this app. It opens again tomorrow.",
    ),
    /** The student tried to turn off HSH's device admin (removal protection). */
    ADMIN_PROTECTED(
        "admin_protected", "HOSTEL POLICY ENFORCEMENT", "Setting Protected",
        "HSH Connect's removal protection can't be turned off while you are signed in. " +
            "It is turned off when you log out. Ask your warden if you need help.",
    ),
    /** The student opened protected permissions or clock settings while signed in. */
    SETTINGS_PROTECTED(
        "settings_protected", "HOSTEL POLICY ENFORCEMENT", "Setting Protected",
        "Changing HSH monitoring permissions or phone Date & Time requires a warden override code.",
    ),
    /** Web browsers restricted by hostel policy. */
    BROWSER_RESTRICTED(
        "browser_restricted", "BROWSER RESTRICTED", "Browser Blocked",
        "Web browsers are restricted by hostel policy. Ask your warden if you need access.",
    ),
    /** Automatic network date/time disabled on a phone with time limits or curfews. */
    CLOCK_TAMPERED(
        "clock_tampered", "CLOCK PROTECTION", "Automatic Time Off",
        "Turn on Automatic date & time in phone settings to continue using apps.",
    );

    companion object {
        fun fromWire(name: String?): BlockReason? = entries.firstOrNull { it.wireName == name }
    }
}

/**
 * Decides whether a package may be in the foreground right now, given the
 * stored [DevicePolicy]: remote lock, installers, blocked apps, bedtime, the
 * daily limit and each app's own time limit. All are enforced on-device so
 * they work offline and don't depend on the backend's clock.
 */
object PolicyEvaluator {
    private const val PROTECTED_CACHE_MS = 5 * 60 * 1000L
    private const val USAGE_CACHE_MS = 15 * 1000L

    /** App stores and package installer packages restricted to prevent unapproved installs. */
    val INSTALLER_PACKAGES = setOf(
        "com.android.packageinstaller",
        "com.google.android.packageinstaller",
        "com.samsung.android.packageinstaller",
        "com.android.vending",
        "com.sec.android.app.samsungapps",
        "com.xiaomi.mipicks",
        "com.heytap.market",
        "com.oppo.market",
        "com.coloros.appmarket",
        "com.vivo.appstore",
        "com.huawei.appmarket",
        "com.aefyr.sai",
        "com.mt.apkinstaller",
        "com.apkmirror.helper.prod",
    )

    /** Common Android web browsers blocked when `restrictBrowsers` is enabled. */
    val BROWSER_PACKAGES = setOf(
        "com.android.chrome",
        "com.chrome.beta",
        "com.chrome.dev",
        "com.sec.android.app.sbrowser",
        "org.mozilla.firefox",
        "com.brave.browser",
        "com.microsoft.emmx",
        "com.opera.browser",
        "com.opera.mini.native",
        "com.duckduckgo.mobile.android",
        "com.mi.globalbrowser",
        "com.android.browser",
        "com.vivo.browser",
        "com.heytap.browser",
        "com.UCMobile.intl",
    )

    fun isAutoTimeEnabled(context: Context): Boolean = runCatching {
        Settings.Global.getInt(context.contentResolver, Settings.Global.AUTO_TIME, 1) != 0
    }.getOrDefault(true)

    /** Packages that must always stay reachable: no phone becomes a brick. */
    private val ALWAYS_PROTECTED = setOf(
        "android",
        "com.android.systemui",
        "com.android.settings",
        "com.samsung.android.settings",
        "com.android.providers.settings",
        "com.android.phone",
        "com.android.server.telecom",
        "com.android.emergency",
        "com.android.incallui",
        "com.samsung.android.incallui",
        "com.google.android.dialer",
        "com.android.dialer",
        "com.samsung.android.dialer",
        "com.android.permissioncontroller",
        "com.google.android.permissioncontroller",
        "com.google.android.gms",
        // Standard Indian UPI & Banking apps — essential transactions should never be blocked
        "com.google.android.apps.nbu.paisa.user", // Google Pay
        "com.phonepe.app",                       // PhonePe
        "net.one97.paytm",                       // Paytm
        "in.org.npci.upiapp",                    // BHIM
        "com.dreamplug.androidapp",              // CRED
        "com.sbi.lotusintouch",                  // YONO SBI
        "com.axis.mobile",                       // Axis Mobile
        "com.msf.kbank.mobile",                  // Kotak Mobile
        "com.csam.icici.bank.imobile",           // iMobile Pay (ICICI)
        "com.snapwork.hdfc",                     // HDFC Bank MobileBanking
    )

    @Volatile private var protectedCache: Set<String> = emptySet()
    @Volatile private var protectedCacheAt = 0L

    @Volatile private var usageMinutesCache = 0
    @Volatile private var usageCacheAt = 0L

    @Volatile private var dynamicBrowserCache: Set<String> = emptySet()
    @Volatile private var dynamicBrowserCacheAt = 0L

    /** Resolves every installed browser dynamically on top of [BROWSER_PACKAGES], excluding [ALWAYS_PROTECTED]. */
    fun browserPackages(context: Context): Set<String> {
        val now = System.currentTimeMillis()
        if (now - dynamicBrowserCacheAt < PROTECTED_CACHE_MS && dynamicBrowserCache.isNotEmpty()) {
            return dynamicBrowserCache
        }
        val pm = context.packageManager
        val found = HashSet<String>(BROWSER_PACKAGES)
        runCatching {
            val httpsView = Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))
                .addCategory(Intent.CATEGORY_BROWSABLE)
            pm.queryIntentActivities(httpsView, PackageManager.MATCH_ALL)
                .forEach { found.add(it.activityInfo.packageName) }
            val browserCategory = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_APP_BROWSER)
            pm.queryIntentActivities(browserCategory, PackageManager.MATCH_ALL)
                .forEach { found.add(it.activityInfo.packageName) }
        }
        found.removeAll(ALWAYS_PROTECTED)
        found.remove("com.android.htmlviewer")
        found.remove(context.packageName)
        dynamicBrowserCache = found
        dynamicBrowserCacheAt = now
        return found
    }

    /** Returns the reason to block [packageName], or null if it is allowed. */
    fun evaluate(context: Context, packageName: String): BlockReason? {
        if (packageName == context.packageName) return null
        if (isProtected(context, packageName)) return null

        val policy = PolicyStore.policy(context)
        if (policy.isLocked) return BlockReason.DEVICE_LOCKED
        if (policy.restrictAppInstalls && packageName in INSTALLER_PACKAGES) {
            if (policy.hasActiveInstallPass || PolicyStore.hasActiveUpdatePass(context)) {
                return null // Allowed during active 15-minute install pass or mandatory app update
            }
            return BlockReason.INSTALLER_BLOCKED
        }
        if (policy.restrictBrowsers && packageName in browserPackages(context)) return BlockReason.BROWSER_RESTRICTED
        if (packageName in policy.blockedPackages) return BlockReason.APP_BLOCKED
        if (policy.hasCurfew && isInBedtime(policy, context = context)) return BlockReason.BEDTIME
        if (!isAutoTimeEnabled(context) && (policy.dailyLimitMinutes > 0 || policy.appLimits.isNotEmpty())) {
            return BlockReason.CLOCK_TAMPERED
        }
        if (packageName in policy.appLimits &&
            AppLimits.reached(policy.appLimits, packageName, appMinutesToday(context, packageName))
        ) {
            return BlockReason.APP_LIMIT
        }
        if (policy.dailyLimitMinutes > 0 && todayMinutes(context) >= policy.dailyLimitMinutes) {
            return BlockReason.DAILY_LIMIT
        }
        return null
    }

    /** Forget cached usage so a fresh sync is reflected immediately. */
    fun invalidateUsage() {
        usageCacheAt = 0L
    }

    // ---------- Curfew (sessions + personal bedtime) ----------

    /**
     * Whether any curfew in [DevicePolicy.effectiveCurfews] is running at
     * [nowMillis] (IST, see [CurfewSchedule]).
     */
    fun isInBedtime(
        policy: DevicePolicy,
        nowMillis: Long = System.currentTimeMillis(),
        context: Context? = null,
    ): Boolean {
        val windows = policy.effectiveCurfews
        if (windows.isEmpty()) return false

        // Anti-tamper: If user disabled automatic network time in Settings, fail closed
        if (context != null) {
            val autoTime = runCatching {
                Settings.Global.getInt(context.contentResolver, Settings.Global.AUTO_TIME, 1)
            }.getOrDefault(1)
            if (autoTime == 0) return true
        }

        return CurfewSchedule.isInCurfew(windows, nowMillis)
    }

    // ---------- Daily limit ----------

    /** Today's total foreground minutes across all non-hostel apps, cached briefly. */
    fun todayMinutes(context: Context): Int {
        refreshUsage(context)
        return usageMinutesCache
    }

    /** Today's foreground minutes of one app (for its own time limit), cached briefly. */
    fun appMinutesToday(context: Context, packageName: String): Int {
        refreshUsage(context)
        return ((usageByAppCache[packageName] ?: 0L) / 60_000L).toInt()
    }

    @Volatile private var usageByAppCache: Map<String, Long> = emptyMap()

    /** Reads today's usage once per [USAGE_CACHE_MS]: the total and each app's share. */
    private fun refreshUsage(context: Context) {
        val now = System.currentTimeMillis()
        if (now - usageCacheAt < USAGE_CACHE_MS) return
        if (!UsageCollector.hasPermission(context)) {
            // No usage access: nothing to measure, so no time rule applies.
            usageMinutesCache = 0
            usageByAppCache = emptyMap()
            return
        }
        val dayStart = UsageCollector.startOfDay(now)
        val snap = runCatching {
            UsageCollector.collect(context, dayStart, UsageCollector.nextDayStart(dayStart))
        }.getOrNull() ?: return
        val apps = snap.appMillis.filterKeys { it != context.packageName }
        usageByAppCache = apps
        usageMinutesCache = (apps.values.sum() / 60_000L).toInt()
        usageCacheAt = now
    }

    // ---------- Protected apps ----------

    fun isProtectedPackage(context: Context, packageName: String): Boolean = isProtected(context, packageName)

    fun isProtected(context: Context, packageName: String): Boolean =
        packageName in ALWAYS_PROTECTED || packageName in protectedPackages(context)

    /**
     * Keyboard, dialer, launcher and friends are resolved from the system at
     * runtime instead of hard-coding OEM package names.
     */
    private fun protectedPackages(context: Context): Set<String> {
        val now = System.currentTimeMillis()
        if (now - protectedCacheAt < PROTECTED_CACHE_MS && protectedCache.isNotEmpty()) return protectedCache

        val pm = context.packageManager
        val set = HashSet<String>()

        // Every enabled keyboard — blocking the IME under lock would stop the
        // student typing in *our* app.
        runCatching {
            val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.enabledInputMethodList.forEach { set.add(it.packageName) }
            Settings.Secure.getString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
                ?.let { ComponentName.unflattenFromString(it)?.packageName }
                ?.let { set.add(it) }
        }

        // Home launchers.
        runCatching {
            val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            pm.queryIntentActivities(home, PackageManager.MATCH_ALL).forEach { set.add(it.activityInfo.packageName) }
        }

        // Dialer / in-call UI (so incoming calls are never blocked).
        runCatching {
            pm.resolveActivity(Intent(Intent.ACTION_DIAL), PackageManager.MATCH_DEFAULT_ONLY)
                ?.activityInfo?.packageName?.let { set.add(it) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val rm = context.getSystemService(Context.ROLE_SERVICE) as RoleManager
                if (rm.isRoleAvailable(RoleManager.ROLE_DIALER)) {
                    pm.queryIntentActivities(
                        Intent(Intent.ACTION_DIAL), PackageManager.MATCH_DEFAULT_ONLY,
                    ).forEach { set.add(it.activityInfo.packageName) }
                }
            }
            pm.resolveActivity(Intent("android.intent.action.DIAL_EMERGENCY"), PackageManager.MATCH_DEFAULT_ONLY)
                ?.activityInfo?.packageName?.let { set.add(it) }
        }

        protectedCache = set
        protectedCacheAt = now
        return set
    }
}
