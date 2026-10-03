package com.example.hsh_app2.screentime

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONArray
import org.json.JSONObject

/** The warden-configured rules this device must enforce. */
data class DevicePolicy(
    val isLocked: Boolean = false,
    val blockedPackages: Set<String> = emptySet(),
    /** 0 = no limit. */
    val dailyLimitMinutes: Int = 0,
    /** "HH:mm" local time, or empty for no curfew. */
    val bedtimeStart: String = "",
    val bedtimeEnd: String = "",
    /** Opaque backend marker so the warden UI can see what the device applied. */
    val version: String = "",
) {
    val hasBedtime: Boolean get() = bedtimeStart.isNotBlank() && bedtimeEnd.isNotBlank()
}

/**
 * Single source of truth for everything the native screen-time stack persists:
 * session (token/base URL), the active [DevicePolicy], sync bookkeeping and
 * the queue of block events awaiting upload.
 *
 * Backed by [EncryptedSharedPreferences] so the bearer token is never on disk
 * in plaintext. Values from the earlier plaintext prefs are migrated once.
 */
object PolicyStore {
    private const val TAG = "PolicyStore"
    private const val FILE = "hsh_screen_time_secure"

    // Legacy plaintext files (pre-encryption) — read once, then wiped.
    private const val LEGACY_SESSION = "hsh_screen_time"
    private const val LEGACY_POLICY = "hsh_screen_time_policy"

    private const val KEY_TOKEN = "token"
    private const val KEY_BASE_URL = "base_url"
    private const val KEY_SENT_DATE = "sent_date"
    private const val KEY_SENT_MILLIS = "sent_millis"
    private const val KEY_SENT_ICONS = "sent_icons"
    private const val KEY_BLOCK_EVENTS = "block_events"

    private const val KEY_IS_LOCKED = "is_locked"
    private const val KEY_BLOCKED = "blocked_packages"
    private const val KEY_DAILY_LIMIT = "daily_limit_minutes"
    private const val KEY_BEDTIME_START = "bedtime_start"
    private const val KEY_BEDTIME_END = "bedtime_end"
    private const val KEY_POLICY_VERSION = "policy_version"
    private const val KEY_POLICY_APPLIED_AT = "policy_applied_at"

    private const val MAX_BLOCK_EVENTS = 200

    @Volatile private var cached: SharedPreferences? = null

    /** Parsed policy, so the blocker's per-window-change check never hits disk/decryption. */
    @Volatile private var policyCache: DevicePolicy? = null

    /** Listeners are told whenever the policy changes so UI can react instantly. */
    private val listeners = mutableSetOf<() -> Unit>()

    fun prefs(context: Context): SharedPreferences {
        cached?.let { return it }
        synchronized(this) {
            cached?.let { return it }
            val app = context.applicationContext
            val p = try {
                val key = MasterKey.Builder(app)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build()
                EncryptedSharedPreferences.create(
                    app, FILE, key,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
                )
            } catch (e: Exception) {
                // Keystore unavailable (rare, some broken ROMs): degrade to plaintext
                // rather than silently stop monitoring.
                Log.e(TAG, "Encrypted prefs unavailable, falling back to plaintext", e)
                app.getSharedPreferences("$FILE.fallback", Context.MODE_PRIVATE)
            }
            migrateLegacy(app, p)
            cached = p
            return p
        }
    }

    private fun migrateLegacy(app: Context, target: SharedPreferences) {
        val session = app.getSharedPreferences(LEGACY_SESSION, Context.MODE_PRIVATE)
        val policy = app.getSharedPreferences(LEGACY_POLICY, Context.MODE_PRIVATE)
        if (session.all.isEmpty() && policy.all.isEmpty()) return

        val e = target.edit()
        session.getString(KEY_TOKEN, null)?.let { if (!target.contains(KEY_TOKEN)) e.putString(KEY_TOKEN, it) }
        session.getString(KEY_BASE_URL, null)?.let { if (!target.contains(KEY_BASE_URL)) e.putString(KEY_BASE_URL, it) }
        session.getString(KEY_SENT_DATE, null)?.let { if (!target.contains(KEY_SENT_DATE)) e.putString(KEY_SENT_DATE, it) }
        session.getString(KEY_SENT_MILLIS, null)?.let { if (!target.contains(KEY_SENT_MILLIS)) e.putString(KEY_SENT_MILLIS, it) }
        if (!target.contains(KEY_IS_LOCKED)) e.putBoolean(KEY_IS_LOCKED, policy.getBoolean(KEY_IS_LOCKED, false))
        policy.getStringSet(KEY_BLOCKED, null)?.let {
            if (!target.contains(KEY_BLOCKED)) e.putString(KEY_BLOCKED, JSONArray(it.toList()).toString())
        }
        e.apply()
        session.edit().clear().apply()
        policy.edit().clear().apply()
        Log.i(TAG, "Migrated legacy plaintext prefs")
    }

    // ---------- Session ----------

    fun saveSession(context: Context, token: String, baseUrl: String) {
        prefs(context).edit()
            .putString(KEY_TOKEN, token)
            .putString(KEY_BASE_URL, baseUrl.trimEnd('/'))
            .apply()
    }

    fun clearSession(context: Context) {
        // Sync bookkeeping is kept on purpose: if the same student logs back in
        // today we must not re-report minutes the backend already has.
        prefs(context).edit().remove(KEY_TOKEN).remove(KEY_BASE_URL).apply()
    }

    fun clearToken(context: Context) = prefs(context).edit().remove(KEY_TOKEN).apply()

    fun token(context: Context): String? = prefs(context).getString(KEY_TOKEN, null)
    fun baseUrl(context: Context): String? = prefs(context).getString(KEY_BASE_URL, null)
    fun hasSession(context: Context): Boolean = !token(context).isNullOrEmpty() && !baseUrl(context).isNullOrEmpty()

    // ---------- Policy ----------

    fun policy(context: Context): DevicePolicy {
        policyCache?.let { return it }
        val p = prefs(context)
        return DevicePolicy(
            isLocked = p.getBoolean(KEY_IS_LOCKED, false),
            blockedPackages = readStringSet(p.getString(KEY_BLOCKED, null)),
            dailyLimitMinutes = p.getInt(KEY_DAILY_LIMIT, 0),
            bedtimeStart = p.getString(KEY_BEDTIME_START, "") ?: "",
            bedtimeEnd = p.getString(KEY_BEDTIME_END, "") ?: "",
            version = p.getString(KEY_POLICY_VERSION, "") ?: "",
        ).also { policyCache = it }
    }

    fun policyAppliedAt(context: Context): Long = prefs(context).getLong(KEY_POLICY_APPLIED_AT, 0L)

    fun savePolicy(context: Context, policy: DevicePolicy) {
        val old = policy(context)
        prefs(context).edit()
            .putBoolean(KEY_IS_LOCKED, policy.isLocked)
            .putString(KEY_BLOCKED, JSONArray(policy.blockedPackages.toList()).toString())
            .putInt(KEY_DAILY_LIMIT, policy.dailyLimitMinutes)
            .putString(KEY_BEDTIME_START, policy.bedtimeStart)
            .putString(KEY_BEDTIME_END, policy.bedtimeEnd)
            .putString(KEY_POLICY_VERSION, policy.version)
            .putLong(KEY_POLICY_APPLIED_AT, System.currentTimeMillis())
            .apply()
        policyCache = policy
        if (old != policy) {
            Log.i(TAG, "Policy updated: $policy")
            synchronized(listeners) { listeners.toList() }.forEach { runCatching { it() } }
        }
    }

    /**
     * Parses a backend payload (either `/screen-time/policies/me` or the echo
     * inside the ping response) and persists it. Accepts both snake_case and
     * camelCase, nested under `data` and/or `policy`, because the API currently
     * emits both.
     */
    fun applyPolicyJson(context: Context, root: JSONObject): DevicePolicy? {
        val data = root.optJSONObject("data") ?: root
        val pol = data.optJSONObject("policy") ?: data
        // No recognisable policy fields at all → leave the stored policy untouched.
        val hasAny = listOf(
            "is_locked", "isLocked", "blockedPackages", "blocked_packages",
            "daily_limit_minutes", "dailyLimitMinutes", "bedtime_start", "bedtimeStart",
        ).any { pol.has(it) || data.has(it) }
        if (!hasAny) return null

        val current = policy(context)
        val blockedArr = data.optJSONArray("blockedPackages")
            ?: data.optJSONArray("blocked_packages")
            ?: pol.optJSONArray("blockedPackages")
            ?: pol.optJSONArray("blocked_packages")
        val blocked = blockedArr?.let { arr ->
            (0 until arr.length()).mapNotNull { arr.optString(it).takeIf { s -> s.isNotBlank() } }.toSet()
        } ?: current.blockedPackages

        val updated = DevicePolicy(
            isLocked = optBool(pol, "is_locked", "isLocked") ?: optBool(data, "is_locked", "isLocked") ?: current.isLocked,
            blockedPackages = blocked,
            dailyLimitMinutes = optInt(pol, "daily_limit_minutes", "dailyLimitMinutes") ?: current.dailyLimitMinutes,
            bedtimeStart = optStr(pol, "bedtime_start", "bedtimeStart") ?: current.bedtimeStart,
            bedtimeEnd = optStr(pol, "bedtime_end", "bedtimeEnd") ?: current.bedtimeEnd,
            version = optStr(pol, "updatedAt", "updated_at") ?: optStr(pol, "version", "policyVersion") ?: current.version,
        )
        savePolicy(context, updated)
        return updated
    }

    fun addPolicyListener(l: () -> Unit) = synchronized(listeners) { listeners.add(l) }
    fun removePolicyListener(l: () -> Unit) = synchronized(listeners) { listeners.remove(l) }

    // ---------- Sync bookkeeping ----------

    fun sentDate(context: Context): String? = prefs(context).getString(KEY_SENT_DATE, null)

    fun sentMillis(context: Context): Map<String, Long> {
        val raw = prefs(context).getString(KEY_SENT_MILLIS, null) ?: return emptyMap()
        return try {
            val json = JSONObject(raw)
            json.keys().asSequence().associateWith { json.getLong(it) }
        } catch (_: Exception) {
            emptyMap()
        }
    }

    fun saveSent(context: Context, date: String, sent: Map<String, Long>) {
        prefs(context).edit()
            .putString(KEY_SENT_DATE, date)
            .putString(KEY_SENT_MILLIS, JSONObject(sent as Map<*, *>).toString())
            .apply()
    }

    /** Packages whose icon the backend already has (so we send each icon once). */
    fun sentIcons(context: Context): Set<String> = readStringSet(prefs(context).getString(KEY_SENT_ICONS, null))

    fun markIconsSent(context: Context, packages: Collection<String>) {
        if (packages.isEmpty()) return
        val all = sentIcons(context) + packages
        prefs(context).edit().putString(KEY_SENT_ICONS, JSONArray(all.toList()).toString()).apply()
    }

    // ---------- Block-event audit queue ----------

    fun recordBlockEvent(context: Context, packageName: String, appName: String, reason: BlockReason) {
        val p = prefs(context)
        val arr = runCatching { JSONArray(p.getString(KEY_BLOCK_EVENTS, "[]")) }.getOrDefault(JSONArray())
        arr.put(
            JSONObject()
                .put("packageName", packageName)
                .put("appName", appName)
                .put("reason", reason.wireName)
                .put("at", System.currentTimeMillis()),
        )
        // Keep the queue bounded if the network is down for a long time.
        val trimmed = if (arr.length() > MAX_BLOCK_EVENTS) {
            JSONArray().also { out -> for (i in arr.length() - MAX_BLOCK_EVENTS until arr.length()) out.put(arr.get(i)) }
        } else arr
        p.edit().putString(KEY_BLOCK_EVENTS, trimmed.toString()).apply()
    }

    fun pendingBlockEvents(context: Context): JSONArray =
        runCatching { JSONArray(prefs(context).getString(KEY_BLOCK_EVENTS, "[]")) }.getOrDefault(JSONArray())

    /** Drops the first [count] events after they were accepted by the backend. */
    fun dropBlockEvents(context: Context, count: Int) {
        if (count <= 0) return
        val arr = pendingBlockEvents(context)
        val rest = JSONArray()
        for (i in count until arr.length()) rest.put(arr.get(i))
        prefs(context).edit().putString(KEY_BLOCK_EVENTS, rest.toString()).apply()
    }

    // ---------- helpers ----------

    private fun readStringSet(raw: String?): Set<String> {
        if (raw.isNullOrEmpty()) return emptySet()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { arr.getString(it) }.toSet()
        } catch (_: Exception) {
            emptySet()
        }
    }

    private fun optBool(o: JSONObject, vararg keys: String): Boolean? {
        for (k in keys) if (o.has(k) && !o.isNull(k)) {
            val v = o.opt(k)
            return when (v) {
                is Boolean -> v
                is Number -> v.toInt() != 0
                is String -> v.equals("true", true) || v == "1"
                else -> null
            }
        }
        return null
    }

    private fun optInt(o: JSONObject, vararg keys: String): Int? {
        for (k in keys) if (o.has(k) && !o.isNull(k)) {
            return when (val v = o.opt(k)) {
                is Number -> v.toInt()
                is String -> v.toDoubleOrNull()?.toInt()
                else -> null
            }
        }
        return null
    }

    private fun optStr(o: JSONObject, vararg keys: String): String? {
        for (k in keys) if (o.has(k) && !o.isNull(k)) return o.optString(k)
        return null
    }
}
