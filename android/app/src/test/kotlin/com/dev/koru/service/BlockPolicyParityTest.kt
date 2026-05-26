package com.dev.koru.service

import com.google.common.truth.Truth.assertWithMessage
import org.junit.Test

/**
 * PARITÀ. Questo test esiste per UN motivo: i 4 decision site native
 * (checkAppBlocking, checkInAppContentBlocking, checkWebsiteBlocking,
 * LockRunnable.checkAndBlock) + il "active now" lato Dart devono condividere
 * ESATTAMENTE la stessa semantica degli intervalli temporali. Storicamente
 * divergevano (chiuso vs half-open vs "from==to mai/sempre"), e ogni
 * divergenza è un buco di enforcement.
 *
 * Pinniamo qui una TRUTH TABLE calcolata a mano sulla semantica canonica
 * (`from==to ⇒ 24h`; `from<to ⇒ [from,to)`; `from>to ⇒ cross-midnight`).
 * Se qualcuno reintroduce una variante (es. intervalli chiusi nel backup, o
 * un `<=` al posto del `<`), questa tabella fallisce.
 *
 * REGOLA: OGNI nuovo decision site DEVE chiamare [BlockPolicyEvaluator] —
 * niente copie della logica di blocco negli adapter.
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
