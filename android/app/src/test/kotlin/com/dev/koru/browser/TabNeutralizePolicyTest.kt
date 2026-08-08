package com.dev.koru.browser

import com.dev.koru.browser.TabNeutralizePolicy.Step
import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Test PURI di [TabNeutralizePolicy] — nessun Android, nessun device.
 *
 * Quello che questi test proteggono davvero e' l'invariante di sicurezza: ogni
 * combinazione che non e' esattamente "barra scrivibile su API >= 30" deve
 * ricadere su [Step.UNSUPPORTED], perche' e' il ramo che degrada al vecchio
 * comportamento (overlay + HOME). Un falso [Step.WRITE_AND_COMMIT] scriverebbe
 * in un nodo qualunque della UI del browser.
 */
class TabNeutralizePolicyTest {

    /// La barra degli indirizzi "sana": editabile, scrivibile, non focalizzata.
    private fun firstStep(
        attempt: Int = 0,
        sdkInt: Int = 34,
        clearUrlAllowed: Boolean = true,
        nodeEditable: Boolean = true,
        supportsSetText: Boolean = true,
        nodeFocusable: Boolean = true,
        nodeFocused: Boolean = false,
    ) = TabNeutralizePolicy.firstStep(
        attempt = attempt,
        sdkInt = sdkInt,
        clearUrlAllowed = clearUrlAllowed,
        nodeEditable = nodeEditable,
        supportsSetText = supportsSetText,
        nodeFocusable = nodeFocusable,
        nodeFocused = nodeFocused,
    )

    // ─── firstStep: il caso buono ───────────────────────────────────────────

    @Test
    fun barraScrivibile_scriveSubitoSenzaChiedereIlFocus() {
        // Il focus farebbe comparire la tastiera SOPRA l'overlay di blocco
        // (TYPE_INPUT_METHOD > TYPE_APPLICATION_OVERLAY): se la scrittura
        // diretta basta, non lo chiediamo.
        assertThat(firstStep()).isEqualTo(Step.WRITE_AND_COMMIT)
    }

    @Test
    fun barraGiaFocalizzata_scriveUgualmente() {
        assertThat(firstStep(nodeFocused = true)).isEqualTo(Step.WRITE_AND_COMMIT)
    }

    // ─── firstStep: i rami che devono degradare ─────────────────────────────

    @Test
    fun sottoApi30_nonSiParte() {
        // Senza ACTION_IME_ENTER scriveremmo un URL che non possiamo
        // confermare: la barra resterebbe sporca e la scheda ferma dov'era.
        assertThat(firstStep(sdkInt = 29)).isEqualTo(Step.UNSUPPORTED)
        assertThat(firstStep(sdkInt = 28)).isEqualTo(Step.UNSUPPORTED)
    }

    @Test
    fun api30_esattamenteAlLimite_siParte() {
        assertThat(firstStep(sdkInt = TabNeutralizePolicy.MIN_SDK_FOR_COMMIT))
            .isEqualTo(Step.WRITE_AND_COMMIT)
    }

    @Test
    fun clearUrlFalse_nonSiTocca() {
        // Browser il cui nodo "url" e' in realta' il titolo della pagina
        // (mx.browser, DuckDuckGo, Dolphin): scriverci non naviga nulla.
        assertThat(firstStep(clearUrlAllowed = false)).isEqualTo(Step.UNSUPPORTED)
    }

    @Test
    fun nodoNonEditabile_nonSiTocca() {
        // Es. il chip `:id/origin` di Chrome: matcha il config ma e' un
        // TextView in sola lettura. Deve passare la mano al config successivo.
        assertThat(firstStep(nodeEditable = false)).isEqualTo(Step.UNSUPPORTED)
    }

    @Test
    fun editabileMaSenzaSetText_provaPrimaIlFocus() {
        assertThat(firstStep(supportsSetText = false)).isEqualTo(Step.FOCUS_THEN_RETRY)
    }

    @Test
    fun editabileSenzaSetTextEGiaFocalizzato_siArrende() {
        // Ha gia' il focus e comunque non espone SET_TEXT: il focus non
        // cambierebbe nulla.
        assertThat(firstStep(supportsSetText = false, nodeFocused = true))
            .isEqualTo(Step.UNSUPPORTED)
    }

    @Test
    fun editabileSenzaSetTextENonFocalizzabile_siArrende() {
        assertThat(firstStep(supportsSetText = false, nodeFocusable = false))
            .isEqualTo(Step.UNSUPPORTED)
    }

    @Test
    fun senzaSetTextAllUltimoTentativo_siArrendeInveceDiRichiedereIlFocus() {
        // Il ramo FOCUS_THEN_RETRY di firstStep e' ricorsivo: un nodo che non
        // espone mai SET_TEXT chiederebbe il focus all'infinito, e il HOME —
        // appeso alla callback di TabNeutralizer — non arriverebbe mai. Cioe'
        // il fallimento della feature diventerebbe un buco di enforcement.
        assertThat(
            firstStep(attempt = TabNeutralizePolicy.MAX_ATTEMPTS - 1, supportsSetText = false),
        ).isEqualTo(Step.UNSUPPORTED)
    }

    // ─── stepAfterFailedCommit ──────────────────────────────────────────────

    @Test
    fun commitRifiutatoAlPrimoGiro_ritentaDopoIlFocus() {
        assertThat(
            TabNeutralizePolicy.stepAfterFailedCommit(
                attempt = 0, nodeFocusable = true, nodeFocused = false,
            ),
        ).isEqualTo(Step.FOCUS_THEN_RETRY)
    }

    @Test
    fun commitRifiutatoConNodoGiaFocalizzato_siArrende() {
        assertThat(
            TabNeutralizePolicy.stepAfterFailedCommit(
                attempt = 0, nodeFocusable = true, nodeFocused = true,
            ),
        ).isEqualTo(Step.UNSUPPORTED)
    }

    @Test
    fun commitRifiutatoSuNodoNonFocalizzabile_siArrende() {
        assertThat(
            TabNeutralizePolicy.stepAfterFailedCommit(
                attempt = 0, nodeFocusable = false, nodeFocused = false,
            ),
        ).isEqualTo(Step.UNSUPPORTED)
    }

    @Test
    fun tettoTentativi_alSecondoGiroSiArrendeSempre() {
        // Il tetto non e' cosmetico: finche' non ci si arrende il HOME resta
        // appeso alla callback, cioe' il blocco NON viene applicato.
        assertThat(
            TabNeutralizePolicy.stepAfterFailedCommit(
                attempt = TabNeutralizePolicy.MAX_ATTEMPTS - 1,
                nodeFocusable = true,
                nodeFocused = false,
            ),
        ).isEqualTo(Step.UNSUPPORTED)
    }

    // ─── costanti ───────────────────────────────────────────────────────────

    @Test
    fun urlNeutro_eUnoSchemaCheTuttiIMotoriAccettano() {
        assertThat(TabNeutralizePolicy.NEUTRAL_URL).isEqualTo("about:blank")
    }

    @Test
    fun finestraDiSospensioneCopreIlPeggiorCasoDiNeutralizzazione() {
        // Worst case = MAX_ATTEMPTS tentativi separati da FOCUS_SETTLE_DELAY_MS.
        // Se la sospensione scadesse prima, il content-change della navigazione
        // smonterebbe l'overlay prima del HOME.
        val worstCaseMs = (TabNeutralizePolicy.MAX_ATTEMPTS - 1) *
            TabNeutralizePolicy.FOCUS_SETTLE_DELAY_MS
        assertThat(TabNeutralizePolicy.SUPPRESS_DISMISS_MS).isGreaterThan(worstCaseMs)
    }
}
