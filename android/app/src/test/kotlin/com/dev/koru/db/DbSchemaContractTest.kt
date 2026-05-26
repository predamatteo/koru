package com.dev.koru.db

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * ARCH-04 — Contract test INTERNO al nativo.
 *
 * Costruisce un DB SQLite con ESATTAMENTE le tabelle/colonne dichiarate in
 * [DbSchema] (un proxy minimale dello schema Drift, costruito SOLO da [DbSchema]
 * così non duplica nomi a mano) ed esegue OGNI read query di [NativeDatabase]
 * contro di esso. Se una query referenzia una colonna/tabella non presente in
 * [DbSchema] (un typo, o una query nuova che dimentica di aggiungere la sua
 * colonna a [DbSchema]) il driver SQLite lancia "no such column/table" e il
 * test fallisce.
 *
 * → Cattura il "drift INTERNO" (NativeDatabase che diverge da DbSchema) a
 *   test-time invece che silenziosamente a runtime (rawQuery fallita ⇒
 *   risultato vuoto ⇒ enforcement spento). Il "drift CROSS-RUNTIME" (Drift che
 *   diverge da DbSchema) è coperto dal test Dart gemello.
 *
 * Robolectric fornisce un'implementazione SQLite reale in-JVM, quindi
 * [NativeDatabase] gira esattamente come on-device, incluso il path
 * [NativeDatabase.findDbFile] (il file finisce in `context.filesDir`).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class DbSchemaContractTest {

    private val ctx: Context get() = ApplicationProvider.getApplicationContext()
    private val profileId = 1

    @Before
    fun setUp() {
        // Chiudi eventuale handle residuo da un test precedente, poi crea da
        // zero il file `koru.db` dove findDbFile lo cerca (filesDir).
        NativeDatabase.close()
        val dbFile = File(ctx.filesDir, DbSchema.DB_NAME)
        if (dbFile.exists()) dbFile.delete()
        createSchemaFromDbSchema(dbFile)
    }

    @After
    fun tearDown() {
        NativeDatabase.close()
        File(ctx.filesDir, DbSchema.DB_NAME).delete()
    }

    // ─── read queries: nessuna deve lanciare "no such column/table" ──────────

    @Test
    fun getEnabledProfiles_matchesSchema() {
        // Non asseriamo sul contenuto (il DB è vuoto): l'asserzione è "non
        // lancia". Una colonna mancante in DbSchema farebbe esplodere qui.
        assertThat(NativeDatabase.getEnabledProfiles(ctx)).isEmpty()
    }

    @Test
    fun getAppRelationsForProfile_matchesSchema() {
        assertThat(NativeDatabase.getAppRelationsForProfile(ctx, profileId)).isEmpty()
    }

    @Test
    fun getIntervalsForProfile_matchesSchema() {
        assertThat(NativeDatabase.getIntervalsForProfile(ctx, profileId)).isEmpty()
    }

    @Test
    fun getUsageLimitsForProfile_matchesSchema() {
        assertThat(NativeDatabase.getUsageLimitsForProfile(ctx, profileId)).isEmpty()
    }

    @Test
    fun getWifiSsidsByProfile_matchesSchema() {
        assertThat(NativeDatabase.getWifiSsidsByProfile(ctx)).isEmpty()
    }

    @Test
    fun getWebsiteRulesForProfile_matchesSchema() {
        assertThat(NativeDatabase.getWebsiteRulesForProfile(ctx, profileId)).isEmpty()
    }

    @Test
    fun getAllWebsiteRulesForEnabledProfiles_matchesSchema() {
        // Esercita anche il JOIN website_rules × profiles (alias w/p): se una
        // delle due tabelle perde una colonna usata nel join/WHERE, fallisce.
        assertThat(NativeDatabase.getAllWebsiteRulesForEnabledProfiles(ctx)).isEmpty()
    }

    @Test
    fun isAdultContentSite_matchesSchema() {
        assertThat(NativeDatabase.isAdultContentSite(ctx, "example.com")).isFalse()
    }

    // ─── write queries (log/usage): stessi nomi colonna, stesso contratto ────

    @Test
    fun writeQueries_matchSchema() {
        val now = System.currentTimeMillis()
        // updateUsedCount tocca usage_limits (UPDATE ... WHERE id = ?).
        NativeDatabase.updateUsedCount(ctx, limitId = 1, usedCount = 5L)
        NativeDatabase.insertBlockSession(ctx, "com.foo", now)
        NativeDatabase.insertRestrictedAccessEvent(
            ctx, "com.foo", eventType = 0, restrictionType = 0, timestamp = now,
        )
        NativeDatabase.insertIntentionEvent(ctx, "com.foo", "Work", now)
        NativeDatabase.insertFocusUsageEvent(ctx, durationMs = 1_000L, timestamp = now)

        // Verifica che gli INSERT siano davvero atterrati nelle colonne giuste
        // (non solo "non ha lanciato"): un INSERT con colonna sbagliata
        // fallirebbe sopra, ma confermiamo anche il round-trip.
        countRows(DbSchema.BlockSessions.TABLE).let { assertThat(it).isEqualTo(1) }
        countRows(DbSchema.RestrictedAccessEvents.TABLE).let { assertThat(it).isEqualTo(1) }
        countRows(DbSchema.IntentionUsageEvents.TABLE).let { assertThat(it).isEqualTo(1) }
        countRows(DbSchema.FocusUsageEvents.TABLE).let { assertThat(it).isEqualTo(1) }
    }

    // ─── helpers ─────────────────────────────────────────────────────────────

    private fun countRows(table: String): Int {
        val db = NativeDatabase.open(ctx)
        db.rawQuery("SELECT COUNT(*) FROM $table", null).use { c ->
            return if (c.moveToFirst()) c.getInt(0) else -1
        }
    }

    /**
     * Crea le tabelle ESCLUSIVAMENTE dalle costanti di [DbSchema]. Costruendo lo
     * schema da DbSchema (non da literal scritti a mano) garantiamo che il test
     * verifichi NativeDatabase vs DbSchema, non DbSchema vs sé stesso: se
     * NativeDatabase usasse un nome non in DbSchema, la colonna mancherebbe qui
     * e la query esploderebbe. Tipi generici (INTEGER/TEXT) — il contratto è sui
     * NOMI, non sull'affinità.
     */
    private fun createSchemaFromDbSchema(dbFile: File) {
        val db = SQLiteDatabase.openOrCreateDatabase(dbFile, null)
        try {
            db.execSQL(createTable(DbSchema.Profiles.TABLE, profileColumns()))
            db.execSQL(createTable(DbSchema.AppProfileRelations.TABLE, appRelationColumns()))
            db.execSQL(createTable(DbSchema.Intervals.TABLE, intervalColumns()))
            db.execSQL(createTable(DbSchema.UsageLimits.TABLE, usageLimitColumns()))
            db.execSQL(createTable(DbSchema.WebsiteRules.TABLE, websiteRuleColumns()))
            db.execSQL(createTable(DbSchema.WifiNetworks.TABLE, wifiColumns()))
            db.execSQL(createTable(DbSchema.AdultContentSites.TABLE, adultColumns()))
            db.execSQL(createTable(DbSchema.BlockSessions.TABLE, blockSessionColumns()))
            db.execSQL(createTable(DbSchema.RestrictedAccessEvents.TABLE, raeColumns()))
            db.execSQL(createTable(DbSchema.IntentionUsageEvents.TABLE, iueColumns()))
            db.execSQL(createTable(DbSchema.FocusUsageEvents.TABLE, fueColumns()))
        } finally {
            db.close()
        }
    }

    private fun createTable(table: String, columns: List<String>): String =
        "CREATE TABLE $table (" + columns.joinToString(", ") { "$it INTEGER" } + ")"

    private fun profileColumns() = with(DbSchema.Profiles) {
        listOf(
            ID, TITLE, TYPE_COMBINATIONS, ON_CONDITIONS, OPERATOR, DAY_FLAGS,
            BLOCK_NOTIFICATIONS, BLOCK_LAUNCH, IS_ENABLED, IS_LOCKED, ON_UNTIL,
            LOCKED_UNTIL, PAUSED_UNTIL, BLOCKING_MODE, BLOCK_UNSUPPORTED_BROWSERS,
            BLOCK_ADULT_CONTENT, COLOR_HEX, EMOJI,
        )
    }

    private fun appRelationColumns() = with(DbSchema.AppProfileRelations) {
        listOf(PACKAGE_NAME, PROFILE_ID, IS_ENABLED, OVERLAY_CONFIG_JSON, BLOCKED_SECTIONS_JSON)
    }

    private fun intervalColumns() = with(DbSchema.Intervals) {
        listOf(ID, PROFILE_ID, FROM_MINUTES, TO_MINUTES, IS_ENABLED)
    }

    private fun usageLimitColumns() = with(DbSchema.UsageLimits) {
        listOf(ID, PROFILE_ID, PERIOD_TYPE, LIMIT_TYPE, LAST_RESET_TIME, ALLOWED_COUNT, USED_COUNT)
    }

    private fun websiteRuleColumns() = with(DbSchema.WebsiteRules) {
        listOf(ID, PROFILE_ID, NAME, BLOCKING_TYPE, IS_ANYWHERE_IN_URL, IS_ENABLED)
    }

    private fun wifiColumns() = with(DbSchema.WifiNetworks) { listOf(PROFILE_ID, SSID) }

    private fun adultColumns() = with(DbSchema.AdultContentSites) { listOf(DOMAIN) }

    private fun blockSessionColumns() = with(DbSchema.BlockSessions) { listOf(NAME, TIMESTAMP) }

    private fun raeColumns() = with(DbSchema.RestrictedAccessEvents) {
        listOf(OCCURRED_AT, DAY_START_DATE, PACKAGE_NAME, EVENT_TYPE, RESTRICTION_TYPE)
    }

    private fun iueColumns() = with(DbSchema.IntentionUsageEvents) {
        listOf(OCCURRED_AT, DAY_START_DATE, PACKAGE_NAME, INTENTION_NAME)
    }

    private fun fueColumns() = with(DbSchema.FocusUsageEvents) {
        listOf(OCCURRED_AT, DAY_START_DATE, DURATION_IN_MS)
    }
}
