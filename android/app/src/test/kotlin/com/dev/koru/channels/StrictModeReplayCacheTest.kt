package com.dev.koru.channels

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * SEC-06 — test della cache locale dei code usati
 * ([StrictModeMethodChannel.pruneUsedCache] / [cacheContainsCode]).
 *
 * Contesto: la fonte AUTORITATIVA del check single-use è la tabella DB
 * `used_backdoor_codes` (durevole, illimitata); le EncryptedSharedPreferences
 * tengono solo una cache veloce. PRIMA la cache era un set flat cappato a 100
 * che evictava entry a CASO → un code ancora valido poteva essere droppato e
 * RIUSATO (SEC-06). ORA ogni entry è `<weekKey>|<code>` e la pruning elimina le
 * settimane PIÙ VECCHIE per prime, MAI la corrente.
 *
 * Le funzioni sotto test sono PURE (nessun DB / SharedPreferences / clock):
 * verifichiamo qui l'invariante centrale — "un code della settimana corrente
 * sopravvive a >100 altri code" — senza dipendere da Robolectric/Keystore. Il
 * ramo DB-autoritativo è esercitato in integrazione (richiede il file Drift,
 * non disponibile in unit test) ma è banale: `INSERT OR IGNORE` + `SELECT
 * EXISTS`. L'unione DB-OR-cache garantisce comunque nessun falso negativo.
 */
class StrictModeReplayCacheTest {

    // Deve combaciare con StrictModeMethodChannel.USED_CACHE_DELIM.
    private val delim = "|"

    private fun entry(week: String, code: String) = "$week$delim$code"

    // -------- cacheContainsCode --------

    @Test
    fun cacheContainsCode_findsCodeRegardlessOfWeek() {
        val entries = setOf(
            entry("2026-W01", "AAAA1111"),
            entry("2026-W05", "BBBB2222"),
            entry("2026-W21", "CCCC3333"),
        )
        assertThat(StrictModeMethodChannel.cacheContainsCode(entries, "BBBB2222")).isTrue()
        assertThat(StrictModeMethodChannel.cacheContainsCode(entries, "CCCC3333")).isTrue()
    }

    @Test
    fun cacheContainsCode_absentCode_isFalse() {
        val entries = setOf(entry("2026-W21", "CCCC3333"))
        assertThat(StrictModeMethodChannel.cacheContainsCode(entries, "ZZZZ9999")).isFalse()
    }

    @Test
    fun cacheContainsCode_emptyCache_isFalse() {
        assertThat(StrictModeMethodChannel.cacheContainsCode(emptySet(), "AAAA1111")).isFalse()
    }

    @Test
    fun cacheContainsCode_doesNotMatchOnWeekPrefixOnly() {
        // Il match è sul SUFFISSO `|<code>`, non su una sottostringa qualsiasi:
        // un code che è prefisso di un altro non deve dare falso positivo.
        val entries = setOf(entry("2026-W21", "ABCD2345EXTRA"))
        assertThat(StrictModeMethodChannel.cacheContainsCode(entries, "ABCD2345")).isFalse()
    }

    // -------- pruneUsedCache: invariante SEC-06 --------

    @Test
    fun pruneUsedCache_currentWeekCodeSurvivesOver100OtherCodes() {
        // IL test di SEC-06: 1 code usato questa settimana, poi 150 code di
        // settimane PASSATE entrano in cache. Con cap 100 la cache va prunata,
        // ma il code della settimana corrente NON deve mai sparire (prima
        // veniva droppato a caso → riusabile).
        val currentWeek = "2026-W21"
        val currentCode = "CURR0001"

        val older = (1..150).map { i ->
            // settimane finte ordinate, tutte < current
            val w = "%02d".format((i % 50) + 1) // W01..W50
            val year = 2020 + (i / 50) // 2020..2022, comunque < 2026
            entry("%04d-W%s".format(year, w), "OLD%05d".format(i))
        }.toSet()

        val all = older + entry(currentWeek, currentCode)
        val pruned = StrictModeMethodChannel.pruneUsedCache(
            entries = all,
            currentWeek = currentWeek,
            maxEntries = 100,
        )

        // Il code corrente è ancora rilevabile come "usato" → NON riusabile.
        assertThat(StrictModeMethodChannel.cacheContainsCode(pruned, currentCode)).isTrue()
        // La cache è stata effettivamente prunata al cap.
        assertThat(pruned.size).isAtMost(100)
    }

    @Test
    fun pruneUsedCache_dropsOldestWeeksFirst() {
        val currentWeek = "2026-W21"
        val entries = setOf(
            entry("2020-W01", "OLDEST00"),
            entry("2023-W10", "MIDDLE00"),
            entry("2026-W20", "RECENT00"),
            entry(currentWeek, "CURRENT0"),
        )
        // Cap = 2: teniamo current + la più recente tra le older, droppiamo le
        // due più vecchie.
        val pruned = StrictModeMethodChannel.pruneUsedCache(
            entries = entries,
            currentWeek = currentWeek,
            maxEntries = 2,
        )
        assertThat(pruned).hasSize(2)
        assertThat(StrictModeMethodChannel.cacheContainsCode(pruned, "CURRENT0")).isTrue()
        assertThat(StrictModeMethodChannel.cacheContainsCode(pruned, "RECENT00")).isTrue()
        // Le più vecchie sono state eliminate.
        assertThat(StrictModeMethodChannel.cacheContainsCode(pruned, "OLDEST00")).isFalse()
        assertThat(StrictModeMethodChannel.cacheContainsCode(pruned, "MIDDLE00")).isFalse()
    }

    @Test
    fun pruneUsedCache_neverEvictsCurrentWeek_evenIfItExceedsCap() {
        // Caso patologico: 5 code usati nella settimana corrente, cap = 2.
        // L'invariante "mai evictare la settimana corrente" vince sul cap:
        // teniamo tutti i 5, anche se superano il tetto (il DB resta comunque
        // la fonte autoritativa illimitata).
        val currentWeek = "2026-W21"
        val entries = (1..5).map { entry(currentWeek, "CUR%05d".format(it)) }.toSet()
        val pruned = StrictModeMethodChannel.pruneUsedCache(
            entries = entries,
            currentWeek = currentWeek,
            maxEntries = 2,
        )
        assertThat(pruned).hasSize(5)
        (1..5).forEach { i ->
            assertThat(StrictModeMethodChannel.cacheContainsCode(pruned, "CUR%05d".format(i))).isTrue()
        }
    }

    @Test
    fun pruneUsedCache_underCap_isNoOp() {
        val currentWeek = "2026-W21"
        val entries = setOf(
            entry("2026-W19", "AAAA1111"),
            entry(currentWeek, "BBBB2222"),
        )
        val pruned = StrictModeMethodChannel.pruneUsedCache(
            entries = entries,
            currentWeek = currentWeek,
            maxEntries = 100,
        )
        assertThat(pruned).isEqualTo(entries)
    }

    @Test
    fun pruneUsedCache_keepsRecentOlderWeeksUpToBudget() {
        // 1 code corrente + 4 settimane passate distinte, cap = 3 → teniamo
        // current (1) + le 2 settimane passate più recenti = 3 totali.
        val currentWeek = "2026-W21"
        val entries = setOf(
            entry("2026-W10", "W10AAAAA"),
            entry("2026-W12", "W12BBBBB"),
            entry("2026-W15", "W15CCCCC"),
            entry("2026-W18", "W18DDDDD"),
            entry(currentWeek, "CURRENT0"),
        )
        val pruned = StrictModeMethodChannel.pruneUsedCache(
            entries = entries,
            currentWeek = currentWeek,
            maxEntries = 3,
        )
        assertThat(pruned).hasSize(3)
        assertThat(StrictModeMethodChannel.cacheContainsCode(pruned, "CURRENT0")).isTrue()
        assertThat(StrictModeMethodChannel.cacheContainsCode(pruned, "W18DDDDD")).isTrue()
        assertThat(StrictModeMethodChannel.cacheContainsCode(pruned, "W15CCCCC")).isTrue()
        // Le due più vecchie cadono.
        assertThat(StrictModeMethodChannel.cacheContainsCode(pruned, "W10AAAAA")).isFalse()
        assertThat(StrictModeMethodChannel.cacheContainsCode(pruned, "W12BBBBB")).isFalse()
    }
}
