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
    val emoji: String,
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
 * stessa app. Non serve cross-process sync custom: SQLite gestisce la
 * concorrenza fra main process e :accessibility process via i fcntl-lock del
 * rollback journal (vedi invariante journal_mode sotto).
 *
 * ─── INVARIANTI CROSS-RUNTIME (ARCH-04) — leggere prima di toccare ──────────
 *
 * Koru ha DUE runtime sullo STESSO file SQLite. Questi accordi sono IMPLICITI
 * nel codice ma NON enforced dal compilatore; sono parte del contratto:
 *
 *  1. **Drift possiede lo schema + le migrazioni.** Il nativo è read-mostly
 *     (legge i profili; scrive solo log/usage su tabelle append-only) e DEVE
 *     conformarsi allo schema che Drift definisce. Ogni nome di tabella/colonna
 *     che il nativo usa è dichiarato UNA VOLTA in [DbSchema] — NON inline qui —
 *     ed è verificato da [DbSchemaContractTest] (drift interno) e dal test Dart
 *     `db_schema_contract_test.dart` (drift cross-runtime). Aggiungere una
 *     query che tocca una colonna nuova ⇒ aggiungerla a [DbSchema] e alla mappa
 *     Dart gemella, altrimenti i contract test falliscono.
 *
 *  2. **journal_mode = DELETE, MAI WAL.** Drift forza `journal_mode=DELETE` nel
 *     suo setup (`app_database.dart::_openConnection`); qui ci allineiamo (vedi
 *     [open]). Se il nativo passasse a WAL, i file ausiliari `-shm`/`-wal`
 *     finirebbero in un layout non interoperabile fra le due librerie SQLite
 *     distinte (sqlite3_flutter_libs lato Flutter vs libsqlite di sistema lato
 *     Android) e Drift crasherebbe con SQLITE_IOERR_SHM* alle SELECT successive.
 *     DELETE usa solo il file principale + un rollback journal temporaneo,
 *     gestito via fcntl-lock compatibili con entrambe.
 *
 *  3. **busy_timeout = 5000 su entrambi i lati.** Garantisce che una scrittura
 *     concorrente di un runtime non faccia fallire subito la lettura dell'altro
 *     con SQLITE_BUSY: chi trova il DB locked riprova fino a 5s.
 */
object NativeDatabase {
    private const val TAG = "NativeDatabase"
    private const val DB_NAME = DbSchema.DB_NAME
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

    @Synchronized
    fun open(context: Context): SQLiteDatabase {
        val current = db
        if (current != null && current.isOpen) return current
        val dbFile = findDbFile(context)
            ?: throw IllegalStateException("Database file not found – Flutter has not created it yet")
        // INVARIANTE 2+3 (vedi doc di classe): NO ENABLE_WRITE_AHEAD_LOGGING.
        // Allineiamo journal_mode=DELETE + busy_timeout=5000 a quanto Drift
        // forza nel suo setup callback. Mettere il file in WAL da qui romperebbe
        // l'interop dei file `-shm`/`-wal` fra le due librerie SQLite e Drift
        // crasherebbe con SQLITE_IOERR_SHM* alle SELECT successive.
        val opened = SQLiteDatabase.openDatabase(
            dbFile.absolutePath, null,
            SQLiteDatabase.OPEN_READWRITE
        )
        try {
            opened.execSQL("PRAGMA journal_mode = DELETE")
            opened.execSQL("PRAGMA busy_timeout = 5000")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to set PRAGMAs: ${e.message}")
        }
        db = opened
        dbPath = dbFile.absolutePath
        Log.i(TAG, "Opened database at ${dbFile.absolutePath}")
        return opened
    }

    @Synchronized
    fun close() {
        db?.close()
        db = null
    }

    fun getEnabledProfiles(context: Context): List<NativeProfile> {
        val database = open(context)
        val out = mutableListOf<NativeProfile>()
        val t = DbSchema.Profiles
        database.rawQuery(
            "SELECT ${t.ID}, ${t.TITLE}, ${t.TYPE_COMBINATIONS}, ${t.ON_CONDITIONS}, " +
                "${t.OPERATOR}, ${t.DAY_FLAGS}, ${t.BLOCK_NOTIFICATIONS}, ${t.BLOCK_LAUNCH}, " +
                "${t.IS_ENABLED}, ${t.IS_LOCKED}, ${t.ON_UNTIL}, ${t.LOCKED_UNTIL}, " +
                "${t.PAUSED_UNTIL}, ${t.BLOCKING_MODE}, ${t.BLOCK_UNSUPPORTED_BROWSERS}, " +
                "${t.BLOCK_ADULT_CONTENT}, ${t.COLOR_HEX}, ${t.EMOJI} " +
                "FROM ${t.TABLE} WHERE ${t.IS_ENABLED} = 1 AND ${t.PAUSED_UNTIL} >= 0",
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
                        emoji = c.getString(17) ?: "NoIcon",
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
        val t = DbSchema.AppProfileRelations
        database.rawQuery(
            "SELECT ${t.PACKAGE_NAME}, ${t.PROFILE_ID}, ${t.IS_ENABLED}, " +
                "${t.OVERLAY_CONFIG_JSON}, ${t.BLOCKED_SECTIONS_JSON} " +
                "FROM ${t.TABLE} WHERE ${t.PROFILE_ID} = ?",
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
        val t = DbSchema.Intervals
        database.rawQuery(
            "SELECT ${t.ID}, ${t.PROFILE_ID}, ${t.FROM_MINUTES}, ${t.TO_MINUTES}, " +
                "${t.IS_ENABLED} FROM ${t.TABLE} " +
                "WHERE ${t.PROFILE_ID} = ? AND ${t.IS_ENABLED} = 1",
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
        val t = DbSchema.UsageLimits
        database.rawQuery(
            "SELECT ${t.ID}, ${t.PROFILE_ID}, ${t.PERIOD_TYPE}, ${t.LIMIT_TYPE}, " +
                "${t.LAST_RESET_TIME}, ${t.ALLOWED_COUNT}, ${t.USED_COUNT} " +
                "FROM ${t.TABLE} WHERE ${t.PROFILE_ID} = ?",
            arrayOf(profileId.toString())
        ).use { c ->
            while (c.moveToNext()) {
                out.add(NativeUsageLimit(c.getInt(0), c.getInt(1), c.getInt(2), c.getInt(3), c.getLong(4), c.getLong(5), c.getLong(6)))
            }
        }
        return out
    }

    fun updateUsedCount(context: Context, limitId: Int, usedCount: Long) {
        val t = DbSchema.UsageLimits
        open(context).execSQL(
            "UPDATE ${t.TABLE} SET ${t.USED_COUNT} = ? WHERE ${t.ID} = ?",
            arrayOf(usedCount, limitId)
        )
    }

    fun insertBlockSession(context: Context, name: String, timestamp: Long) {
        val t = DbSchema.BlockSessions
        open(context).execSQL(
            "INSERT INTO ${t.TABLE} (${t.NAME}, ${t.TIMESTAMP}) VALUES (?, ?)",
            arrayOf(name, timestamp)
        )
    }

    /**
     * Event type: 0 = BLOCK_TRIGGERED, 1 = BLOCK_SKIPPED.
     * Restriction type: 0 = APP, 1 = SECTION, 2 = WEBSITE, 3 = USAGE_LIMIT, 4 = FOCUS_MODE.
     */
    fun insertRestrictedAccessEvent(
        context: Context,
        packageName: String,
        eventType: Int,
        restrictionType: Int,
        timestamp: Long,
    ) {
        val cal = java.util.Calendar.getInstance().apply { timeInMillis = timestamp }
        val y = cal.get(java.util.Calendar.YEAR).toString().padStart(4, '0')
        val m = (cal.get(java.util.Calendar.MONTH) + 1).toString().padStart(2, '0')
        val d = cal.get(java.util.Calendar.DAY_OF_MONTH).toString().padStart(2, '0')
        val dayKey = "$y-$m-$d"
        val t = DbSchema.RestrictedAccessEvents
        open(context).execSQL(
            "INSERT INTO ${t.TABLE} " +
                "(${t.OCCURRED_AT}, ${t.DAY_START_DATE}, ${t.PACKAGE_NAME}, " +
                "${t.EVENT_TYPE}, ${t.RESTRICTION_TYPE}) " +
                "VALUES (?, ?, ?, ?, ?)",
            arrayOf(timestamp, dayKey, packageName, eventType, restrictionType),
        )
    }

    /**
     * Log di una intention scelta dall'utente sull'overlay di blocco.
     * Alimenta il "Top intentions" nelle statistiche.
     */
    fun insertIntentionEvent(
        context: Context,
        packageName: String,
        intentionName: String,
        timestamp: Long,
    ) {
        val cal = java.util.Calendar.getInstance().apply { timeInMillis = timestamp }
        val y = cal.get(java.util.Calendar.YEAR).toString().padStart(4, '0')
        val m = (cal.get(java.util.Calendar.MONTH) + 1).toString().padStart(2, '0')
        val d = cal.get(java.util.Calendar.DAY_OF_MONTH).toString().padStart(2, '0')
        val dayKey = "$y-$m-$d"
        val t = DbSchema.IntentionUsageEvents
        open(context).execSQL(
            "INSERT INTO ${t.TABLE} " +
                "(${t.OCCURRED_AT}, ${t.DAY_START_DATE}, ${t.PACKAGE_NAME}, ${t.INTENTION_NAME}) " +
                "VALUES (?, ?, ?, ?)",
            arrayOf(timestamp, dayKey, packageName, intentionName),
        )
    }

    /**
     * Registra una sessione di focus (quick block o pomodoro work phase)
     * completata o stoppata, con la durata effettivamente maturata.
     * Alimenta il "Focus time" nelle statistiche.
     */
    fun insertFocusUsageEvent(
        context: Context,
        durationMs: Long,
        timestamp: Long,
    ) {
        if (durationMs <= 0) return
        val cal = java.util.Calendar.getInstance().apply { timeInMillis = timestamp }
        val y = cal.get(java.util.Calendar.YEAR).toString().padStart(4, '0')
        val m = (cal.get(java.util.Calendar.MONTH) + 1).toString().padStart(2, '0')
        val d = cal.get(java.util.Calendar.DAY_OF_MONTH).toString().padStart(2, '0')
        val dayKey = "$y-$m-$d"
        val t = DbSchema.FocusUsageEvents
        open(context).execSQL(
            "INSERT INTO ${t.TABLE} " +
                "(${t.OCCURRED_AT}, ${t.DAY_START_DATE}, ${t.DURATION_IN_MS}) " +
                "VALUES (?, ?, ?)",
            arrayOf(timestamp, dayKey, durationMs),
        )
    }

    /// SSID WiFi vincolate per ogni profilo: profileId → Set<ssid>.
    /// Profilo senza entry → nessun vincolo wifi.
    fun getWifiSsidsByProfile(context: Context): Map<Int, Set<String>> {
        val out = mutableMapOf<Int, MutableSet<String>>()
        val t = DbSchema.WifiNetworks
        open(context).rawQuery(
            "SELECT ${t.PROFILE_ID}, ${t.SSID} FROM ${t.TABLE}", null
        ).use { c ->
            while (c.moveToNext()) {
                val pid = c.getInt(0)
                val ssid = c.getString(1)
                out.getOrPut(pid) { mutableSetOf() }.add(ssid)
            }
        }
        return out
    }

    fun getWebsiteRulesForProfile(context: Context, profileId: Int): List<NativeWebsiteRule> {
        val out = mutableListOf<NativeWebsiteRule>()
        val t = DbSchema.WebsiteRules
        open(context).rawQuery(
            "SELECT ${t.ID}, ${t.PROFILE_ID}, ${t.NAME}, ${t.BLOCKING_TYPE}, " +
                "${t.IS_ANYWHERE_IN_URL}, ${t.IS_ENABLED} " +
                "FROM ${t.TABLE} WHERE ${t.PROFILE_ID} = ? AND ${t.IS_ENABLED} = 1",
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
        val w = DbSchema.WebsiteRules
        val p = DbSchema.Profiles
        open(context).rawQuery(
            "SELECT w.${w.ID}, w.${w.PROFILE_ID}, w.${w.NAME}, w.${w.BLOCKING_TYPE}, " +
                "w.${w.IS_ANYWHERE_IN_URL}, w.${w.IS_ENABLED} " +
                "FROM ${w.TABLE} w INNER JOIN ${p.TABLE} p ON w.${w.PROFILE_ID} = p.${p.ID} " +
                "WHERE p.${p.IS_ENABLED} = 1 AND p.${p.PAUSED_UNTIL} >= 0 AND w.${w.IS_ENABLED} = 1",
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
        val t = DbSchema.AdultContentSites
        open(context).rawQuery(
            "SELECT EXISTS(SELECT 1 FROM ${t.TABLE} WHERE ${t.DOMAIN} = ? OR ${t.DOMAIN} = ?)",
            arrayOf(d, "www.$d")
        ).use { c ->
            return c.moveToNext() && c.getInt(0) == 1
        }
    }
}
