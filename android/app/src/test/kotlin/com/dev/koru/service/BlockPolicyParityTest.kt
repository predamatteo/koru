package com.dev.koru.service

import com.google.common.truth.Truth.assertWithMessage
import org.junit.Test

/**
 * Pinning della SEMANTICA CANONICA degli intervalli temporali.
 *
 * Cosa garantisce DAVVERO questo test (e nient'altro): che
 * [BlockPolicyEvaluator.isNowInInterval] — l'unica implementazione condivisa
 * da tutti i decision site native — rispetti la truth table calcolata a mano
 * (`from==to ⇒ 24h`; `from<to ⇒ [from,to)` half-open; `from>to ⇒
 * cross-midnight` con end escluso). Storicamente questa logica divergeva tra
 * i path (chiuso vs half-open vs "from==to mai/sempre"); se qualcuno
 * reintroduce una variante QUI (es. un `<=` al posto del `<`), la tabella
 * fallisce. È un test PURO sulla funzione di intervallo, senza Android.
 *
 * Cosa NON garantisce: NON verifica che i 4 decision site
 * (checkAppBlocking, checkInAppContentBlocking, checkWebsiteBlocking,
 * LockRunnable.checkAndBlock) chiamino effettivamente questo evaluator — è un
 * test di valore, non struttura. La regola "OGNI nuovo decision site DEVE
 * passare per [BlockPolicyEvaluator], niente copie della logica negli adapter"
 * è un invariante di progetto fatto rispettare in REVIEW, non da questo test.
 *
 * Parità cross-runtime Kotlin↔Dart: il lato Dart pinna la stessa truth table
 * canonica in `test/utils/schedule_utils_test.dart`
 * (ScheduleUtils.isNowInRange), così una divergenza tra i due runtime fa
 * fallire l'una o l'altra suite.
 */
class BlockPolicyParityTest {

    /** Una riga della truth table: input + atteso calcolato a mano. */
    private data class Row(val now: Int, val from: Int, val to: Int, val expected: Boolean)

    private val truthTable = listOf(
        // --- half-open same-day [540, 1020) = 09:00..17:00 ---
        Row(539, 540, 1020, false), // un minuto prima dello start
        Row(540, 540, 1020, true),  // start incluso
        Row(1019, 540, 1020, true), // ultimo minuto dentro
        Row(1020, 540, 1020, false), // end ESCLUSO
        Row(1021, 540, 1020, false),
        Row(0, 540, 1020, false),   // mezzanotte fuori

        // --- from == to ⇒ 24h ---
        Row(0, 600, 600, true),
        Row(600, 600, 600, true),
        Row(1439, 600, 600, true),

        // --- cross-midnight [1320, 360) = 22:00..06:00 ---
        Row(1319, 1320, 360, false), // un minuto prima dello start
        Row(1320, 1320, 360, true),  // start incluso
        Row(1439, 1320, 360, true),  // 23:59 dentro
        Row(0, 1320, 360, true),     // mezzanotte dentro
        Row(359, 1320, 360, true),   // 05:59 dentro
        Row(360, 1320, 360, false),  // 06:00 end ESCLUSO
        Row(720, 1320, 360, false),  // mezzogiorno fuori
    )

    @Test
    fun isNowInInterval_matchesHandComputedTruthTable() {
        for (r in truthTable) {
            val actual = BlockPolicyEvaluator.isNowInInterval(r.now, r.from, r.to)
            assertWithMessage("isNowInInterval(now=${r.now}, from=${r.from}, to=${r.to})")
                .that(actual)
                .isEqualTo(r.expected)
        }
    }
}
