package com.dev.koru.db

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.io.File

/**
 * Read-only snapshot DTOs of the profile tables, populated from Drift-managed
 * SQLite database by the blocking engine running inside the accessibility
 * service process.
 */
data class NativeProfile(
    val id: Int,
    val title: String,
    val typeCombinations: Int,
    val onConditions: Int,
    val operator: Int,
    val dayFlags: Int,
    val blockNotifications: Boolean,
    val blockLaunch: Boolean,
    val isEnabled: Boolean,
    val isLocked: Boolean,
    val onUntil: Long,
    val lockedUntil: Long,
    val pausedUntil: Long,
    val blockingMode: Int,
    val blockUnsupportedBrowsers: Boolean,
    val blockAdultContent: Boolean,
    val colorHex: String,
)

data class NativeAppRelation(
    val packageName: String,
    val profileId: Int,
    val isEnabled: Boolean,
    val overlayConfigJson: String?,
    val blockedSectionsJson: String?,
)

data class NativeInterval(
    val id: Int,
    val profileId: Int,
    val fromMinutes: Int,
    val toMinutes: Int,
    val isEnabled: Boolean,
)

data class NativeUsageLimit(
    val id: Int,
    val profileId: Int,
    val periodType: Int,
    val limitType: Int,
    val lastResetTime: Long,
    val allowedCount: Long,
    val usedCount: Long,
)

data class NativeWebsiteRule(
    val id: Int,
    val profileId: Int,
    val name: String,
    val blockingType: Int,
    val isAnywhereInUrl: Boolean,
    val isEnabled: Boolean,
)

/**
 * Accesso read-only (e occasionalmente write per log/usage) al database Drift
 * `koru.db` da parte del processo AccessibilityService/ForegroundService.
 *
 * Drift crea il file con path_provider.getApplicationDocumentsDirectory() che
 * su Android risolve a context.filesDir — accessibile a tutti i processi della
 * stessa app. Non serve cross-process sync custom: SQLite con WAL gestisce
 * la concorrenza fra main process e :accessibility process.
 */
object NativeDatabase {
    private const val TAG = "NativeDatabase"
    private const val DB_NAME = "koru.db"
    private var db: SQLiteDatabase? = null
    private var dbPath: String? = null

    private fun findDbFile(context: Context): File? {
        val filesDir = File(context.filesDir, DB_NAME)
        if (filesDir.exists()) return filesDir
        val flutterDir = File(context.getDir("flutter", Context.MODE_PRIVATE), DB_NAME)
        if (flutterDir.exists()) return flutterDir
        val dbDir = context.getDatabasePath(DB_NAME)
        if (dbDir.exists()) return dbDir
        Log.w(TAG, "DB not found in any of: ${filesDir.absolutePath}, ${flutterDir.absolutePath}, ${dbDir.absolutePath}")
        return null
    }

    fun open(context: Context): SQLiteDatabase {
        if (db != null && db!!.isOpen) return db!!
        val dbFile = findDbFile(context)
            ?: throw IllegalStateException("Database file not found – Flutter has not created it yet")
        db = SQLiteDatabase.openDatabase(
            dbFile.absolutePath, null,
            SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.ENABLE_WRITE_AHEAD_LOGGING
        )
        dbPath = dbFile.absolutePath
        Log.i(TAG, "Opened database at ${dbFile.absolutePath}")
        return db!!
    }

    fun close() {
        db?.close()
        db = null
    }

    fun getEnabledProfiles(context: Context): List<NativeProfile> {
        val database = open(context)
        val out = mutableListOf<NativeProfile>()
        database.rawQuery(
            "SELECT id, title, type_combinations, on_conditions, operator, day_flags, " +
                "block_notifications, block_launch, is_enabled, is_locked, on_until, " +
                "locked_until, paused_until, blocking_mode, block_unsupported_browsers, " +
                "block_adult_content, color_hex " +
                "FROM profiles WHERE is_enabled = 1 AND paused_until >= 0",
            null
        ).use { c ->
            while (c.moveToNext()) {
                out.add(
                    NativeProfile(
                        id = c.getInt(0),
                        title = c.getString(1),
                        typeCombinations = c.getInt(2),
                        onConditions = c.getInt(3),
                        operator = c.getInt(4),
                        dayFlags = c.getInt(5),
                        blockNotifications = c.getInt(6) == 1,
                        blockLaunch = c.getInt(7) == 1,
                        isEnabled = c.getInt(8) == 1,
                        isLocked = c.getInt(9) == 1,
                        onUntil = c.getLong(10),
                        lockedUntil = c.getLong(11),
                        pausedUntil = c.getLong(12),
                        blockingMode = c.getInt(13),
                        blockUnsupportedBrowsers = c.getInt(14) == 1,
                        blockAdultContent = c.getInt(15) == 1,
                        colorHex = c.getString(16) ?: "#5C8262",
                    )
                )
            }
        }
        Log.d(TAG, "getEnabledProfiles: found ${out.size}")
        return out
    }

    fun getAppRelationsForProfile(context: Context, profileId: Int): List<NativeAppRelation> {
        val database = open(context)
        val out = mutableListOf<NativeAppRelation>()
        database.rawQuery(
            "SELECT package_name, profile_id, is_enabled, overlay_config_json, blocked_sections_json " +
                "FROM app_profile_relations WHERE profile_id = ?",
            arrayOf(profileId.toString())
        ).use { c ->
            while (c.moveToNext()) {
                out.add(
                    NativeAppRelation(
                        packageName = c.getString(0),
                        profileId = c.getInt(1),
                        isEnabled = c.getInt(2) == 1,
                        overlayConfigJson = if (c.isNull(3)) null else c.getString(3),
                        blockedSectionsJson = if (c.isNull(4)) null else c.getString(4),
                    )
                )
            }
        }
        return out
    }

    fun getIntervalsForProfile(context: Context, profileId: Int): List<NativeInterval> {
        val database = open(context)
        val out = mutableListOf<NativeInterval>()
        database.rawQuery(
            "SELECT id, profile_id, from_minutes, to_minutes, is_enabled FROM intervals " +
                "WHERE profile_id = ? AND is_enabled = 1",
            arrayOf(profileId.toString())
        ).use { c ->
            while (c.moveToNext()) {
                out.add(NativeInterval(c.getInt(0), c.getInt(1), c.getInt(2), c.getInt(3), c.getInt(4) == 1))
            }
        }
        return out
    }

    fun getUsageLimitsForProfile(context: Context, profileId: Int): List<NativeUsageLimit> {
        val database = open(context)
        val out = mutableListOf<NativeUsageLimit>()
        database.rawQuery(
            "SELECT id, profile_id, period_type, limit_type, last_reset_time, allowed_count, used_count " +
                "FROM usage_limits WHERE profile_id = ?",
            arrayOf(profileId.toString())
        ).use { c ->
            while (c.moveToNext()) {
                out.add(NativeUsageLimit(c.getInt(0), c.getInt(1), c.getInt(2), c.getInt(3), c.getLong(4), c.getLong(5), c.getLong(6)))
            }
        }
        return out
    }

    fun updateUsedCount(context: Context, limitId: Int, usedCount: Long) {
        open(context).execSQL(
            "UPDATE usage_limits SET used_count = ? WHERE id = ?",
            arrayOf(usedCount, limitId)
        )
    }

    fun insertBlockSession(context: Context, name: String, timestamp: Long) {
        open(context).execSQL(
            "INSERT INTO block_sessions (name, timestamp) VALUES (?, ?)",
            arrayOf(name, timestamp)
        )
    }

    fun getWebsiteRulesForProfile(context: Context, profileId: Int): List<NativeWebsiteRule> {
        val out = mutableListOf<NativeWebsiteRule>()
        open(context).rawQuery(
            "SELECT id, profile_id, name, blocking_type, is_anywhere_in_url, is_enabled " +
                "FROM website_rules WHERE profile_id = ? AND is_enabled = 1",
            arrayOf(profileId.toString())
        ).use { c ->
            while (c.moveToNext()) {
                out.add(NativeWebsiteRule(c.getInt(0), c.getInt(1), c.getString(2), c.getInt(3), c.getInt(4) == 1, c.getInt(5) == 1))
            }
        }
        return out
    }

    fun getAllWebsiteRulesForEnabledProfiles(context: Context): Map<Int, List<NativeWebsiteRule>> {
        val result = mutableMapOf<Int, MutableList<NativeWebsiteRule>>()
        open(context).rawQuery(
            "SELECT w.id, w.profile_id, w.name, w.blocking_type, w.is_anywhere_in_url, w.is_enabled " +
                "FROM website_rules w INNER JOIN profiles p ON w.profile_id = p.id " +
                "WHERE p.is_enabled = 1 AND p.paused_until >= 0 AND w.is_enabled = 1",
            null
        ).use { c ->
            while (c.moveToNext()) {
                val r = NativeWebsiteRule(
                    c.getInt(0), c.getInt(1), c.getString(2),
                    c.getInt(3), c.getInt(4) == 1, c.getInt(5) == 1
                )
                result.getOrPut(r.profileId) { mutableListOf() }.add(r)
            }
        }
        return result
    }

    fun isAdultContentSite(context: Context, domain: String): Boolean {
        val d = domain.removePrefix("www.")
        open(context).rawQuery(
            "SELECT EXISTS(SELECT 1 FROM adult_content_sites WHERE domain = ? OR domain = ?)",
            arrayOf(d, "www.$d")
        ).use { c ->
            return c.moveToNext() && c.getInt(0) == 1
        }
    }
}
