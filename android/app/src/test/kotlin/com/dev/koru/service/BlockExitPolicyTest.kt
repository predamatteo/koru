package com.dev.koru.service

import com.dev.koru.overlay.BlockReason
import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * [BlockExitPolicy] + guard strutturale sui suoi call site.
 *
 * Il bug che questi test bloccano: il cap giornaliero usciva con BACK. L'utente
 * veniva colpito dal limite mentre era dentro l'app, BACK pop-pava una sola
 * schermata, l'app restava in foreground, il window-event successivo ri-bloccava
 * → "back, back, back" su per lo stack invece di una chiusura.
 *
 * La parte pura è banale da testare; la parte che vale è la seconda, perché la
 * regressione originale non è stata "una funzione sbagliata" ma "un call site
 * che passava il booleano a mano e si è disallineato dagli altri". Come in
 * [MediaSilenceParityTest], quella regola vive come scan del sorgente: un unit
 * test non può istanziare [KoruAccessibilityService].
 */
class BlockExitPolicyTest {

    @Test
    fun capGiornaliero_esceConHomeNonConBack() {
        // Il caso del bug: l'utente è già dentro l'app quando il cap scatta.
        assertThat(BlockExitPolicy.forceHomeFor(BlockReason.USAGE_LIMIT)).isTrue()
    }

    @Test
    fun aperturaDallIcona_restaSuBackPerPreservareLaPaginaDelLauncher() {
        assertThat(BlockExitPolicy.forceHomeFor(BlockReason.APP_BLOCKED)).isFalse()
    }

    @Test
    fun sezioneSitoEBypassScaduto_esconoConHome() {
        assertThat(BlockExitPolicy.forceHomeFor(BlockReason.SECTION_BLOCKED)).isTrue()
        assertThat(BlockExitPolicy.forceHomeFor(BlockReason.WEBSITE_BLOCKED)).isTrue()
        assertThat(BlockExitPolicy.forceHomeFor(BlockReason.BYPASS_EXPIRED)).isTrue()
    }

    @Test
    fun appBlockedELunicoRamoMorbido() {
        // Invariante, non ridondanza con i test sopra: se domani si aggiunge un
        // reason, il `when` esaustivo obbliga a mapparlo ma non a pensarci.
        // Questo test fallisce se il nuovo reason nasce "morbido" per inerzia —
        // BACK è corretto SOLO quando l'app non è ancora davvero aperta.
        val morbidi = BlockReason.values().filterNot { BlockExitPolicy.forceHomeFor(it) }
        assertThat(morbidi).containsExactly(BlockReason.APP_BLOCKED)
    }

    // -------------------------------------------------------------------------
    // Guard strutturale: la scelta BACK/HOME dei rami di blocco deve passare
    // dalla policy, non da un booleano scritto a mano.
    // -------------------------------------------------------------------------

    private fun mainKotlin(relative: String): File {
        // I test girano con cwd = module dir (android/app) oppure repo root a
        // seconda dell'invocazione; risaliamo finché troviamo il sorgente.
        val candidates = listOf(
            File("src/main/kotlin/com/dev/koru/$relative"),
            File("android/app/src/main/kotlin/com/dev/koru/$relative"),
            File("app/src/main/kotlin/com/dev/koru/$relative"),
        )
        candidates.firstOrNull { it.exists() }?.let { return it }
        var dir: File? = File(".").absoluteFile
        while (dir != null) {
            val f = File(dir, "android/app/src/main/kotlin/com/dev/koru/$relative")
            if (f.exists()) return f
            dir = dir.parentFile
        }
        throw AssertionError("Source not found for $relative (cwd=${File(".").absolutePath})")
    }

    /// Righe di CODICE con un `forceHome = <literal>` — il pattern che ha
    /// prodotto il bug. I commenti sono esclusi: descrivono la scelta della
    /// policy (`forceHome=true (vedi [BlockExitPolicy])`), non la fanno.
    private fun hardcodedForceHome(source: String): List<String> {
        val literal = Regex("""forceHome\s*=\s*(true|false)\b""")
        return source.lines().mapIndexedNotNull { idx, line ->
            val code = line.trim()
            if (code.startsWith("//") || code.startsWith("*")) return@mapIndexedNotNull null
            if (!literal.containsMatchIn(code)) return@mapIndexedNotNull null
            "${idx + 1}: $code"
        }
    }

    @Test
    fun accessibilityService_nessunRamoDecideDaSoloBackOHome() {
        val src = mainKotlin("service/KoruAccessibilityService.kt").readText()
        assertThat(hardcodedForceHome(src)).isEmpty()
    }

    @Test
    fun overlayView_nessunRamoDecideDaSoloBackOHome() {
        // L'uscita "a mano" (bottone Don't open / Close app, swipe-up) deve
        // usare la stessa policy dei rami automatici: era proprio la divergenza
        // fra le due a rendere il cap incoerente con sé stesso.
        val src = mainKotlin("service/OverlayView.kt").readText()
        assertThat(hardcodedForceHome(src)).isEmpty()
        assertThat(src).contains("BlockExitPolicy.forceHomeFor(")
    }

    @Test
    fun accessibilityService_usaLaPolicySuTuttiIRamiDiBlocco() {
        // Sanity: se un refactor rimuovesse le chiamate invece di sistemarle,
        // il test sopra passerebbe a vuoto. I rami sono quattro (app, cap,
        // sezione, sito); BYPASS_EXPIRED esce dall'overlay, non da qui.
        val src = mainKotlin("service/KoruAccessibilityService.kt").readText()
        assertThat(src.split("BlockExitPolicy.forceHomeFor(").size - 1).isAtLeast(4)
    }
}
