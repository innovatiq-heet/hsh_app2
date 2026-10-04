package com.example.hsh_app2.callerid

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log

/** One phonebook hit for an incoming number. */
data class CallerMatch(
    val studentId: String,
    val name: String,
    /** "Room B-204" / group — whatever the directory put in `department`. */
    val place: String,
    /** Student / Father / Mother / WhatsApp. */
    val relation: String,
    val normalized: String,
) {
    val headline: String get() = if (relation == "Student") name else "$relation of $name"
}

/**
 * Reads the phonebook cache that Flutter's sqflite writes
 * (`databases/student_phonebook_cache.db`) — read-only, no copy, so caller ID
 * is always as fresh as the last sync.
 */
object CallerIdStore {
    private const val TAG = "CallerIdStore"
    private const val PREFS = "hsh_caller_id"
    private const val KEY_ACTIVE = "active"
    private const val DB_NAME = "student_phonebook_cache.db"

    fun isActive(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ACTIVE, false)

    fun setActive(context: Context, active: Boolean) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ACTIVE, active).apply()

    /** Last 10 national digits, matching `PhoneNumberNormalizer.normalize` in Dart. */
    fun normalize(raw: String?): String? {
        if (raw == null) return null
        var d = raw.filter { it.isDigit() }
        if (d.isEmpty()) return null
        if (d.length > 10 && d.startsWith("00")) d = d.substring(2)
        if (d.length > 10 && d.startsWith("91")) d = d.substring(2)
        if (d.length > 10 && d.startsWith("0")) d = d.substring(1)
        return if (d.length == 10) d else null
    }

    fun relation(label: String?): String {
        val l = label?.lowercase() ?: return "Student"
        return when {
            "father" in l -> "Father"
            "mother" in l -> "Mother"
            "whatsapp" in l -> "WhatsApp"
            "guardian" in l || "parent" in l -> "Guardian"
            else -> "Student"
        }
    }

    /** All students this number belongs to (siblings can share a parent's phone). */
    fun lookup(context: Context, rawNumber: String?): List<CallerMatch> {
        val normalized = normalize(rawNumber) ?: return emptyList()
        val file = context.getDatabasePath(DB_NAME)
        if (!file.exists()) return emptyList()

        var db: SQLiteDatabase? = null
        return try {
            db = SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY)
            db.rawQuery(
                """SELECT student_id, name, department, phone_label, phone_normalized, phone
                   FROM student_cache
                   WHERE phone_normalized = ? OR phone LIKE ?
                   ORDER BY is_primary DESC LIMIT 5""",
                arrayOf(normalized, "%$normalized"),
            ).use { c ->
                val out = ArrayList<CallerMatch>()
                while (c.moveToNext()) {
                    out.add(
                        CallerMatch(
                            studentId = c.getString(0) ?: "",
                            name = c.getString(1) ?: "",
                            place = c.getString(2) ?: "",
                            relation = relation(c.getString(3)),
                            normalized = normalized,
                        ),
                    )
                }
                // The LIKE fallback can over-match on short suffixes; keep exact-normalised rows first.
                out.distinctBy { it.studentId + it.relation }
            }
        } catch (e: Exception) {
            Log.w(TAG, "lookup failed: ${e.message}")
            emptyList()
        } finally {
            db?.close()
        }
    }
}
