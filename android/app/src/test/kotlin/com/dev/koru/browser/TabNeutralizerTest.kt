package com.dev.koru.browser

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityNodeInfo.AccessibilityAction
import com.google.common.truth.Truth.assertThat
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import io.mockk.verifyOrder
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.time.Duration

/**
 * Comportamento di [TabNeutralizer] con [AccessibilityNodeInfo] mockato — stessa
 * tecnica di `InstagramDetectorTest`: costruiamo alberi minimi che espongono
 * esattamente le capability che ci interessano.
 *
 * Il contratto piu' importante testato qui e' che `onDone` venga invocata
 * **sempre**, anche sui rami di fallimento: e' a quella callback che il service
 * appende il `performGoHomeForBlock`, quindi una neutralizzazione che non
 * risponde equivarrebbe a un blocco mai applicato.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class TabNeutralizerTest {

    private val imeEnterId = AccessibilityAction.ACTION_IME_ENTER.id

    private fun config(viewId: String = ":id/url_bar", clearUrl: Boolean = true) = BrowserConfig(
        packageName = "com.android.chrome",
        viewId = viewId,
        viewType = 0,
        detectionMethod = "VIEW_ID",
        extractionMethod = "TEXT",
        clearUrl = clearUrl,
    )

    /// Barra degli indirizzi credibile: editabile, espone SET_TEXT, non focalizzata.
    private fun urlBarNode(
        editable: Boolean = true,
        setText: Boolean = true,
        focusable: Boolean = true,
        focused: Boolean = false,
        text: String = "reddit.com",
    ): AccessibilityNodeInfo {
        val node = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { node.isEditable } returns editable
        every { node.isFocusable } returns focusable
        every { node.isFocused } returns focused
        every { node.text } returns text
        every { node.actionList } returns
            if (setText) listOf(AccessibilityAction.ACTION_SET_TEXT) else emptyList()
        return node
    }

    private fun rootFinding(vararg nodes: AccessibilityNodeInfo): AccessibilityNodeInfo {
        val root = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { root.findAccessibilityNodeInfosByViewId(any()) } returns nodes.toList()
        return root
    }

    /// Root che non trova nulla per nessun view-id.
    private fun rootFindingNothing(): AccessibilityNodeInfo {
        val root = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { root.findAccessibilityNodeInfosByViewId(any()) } returns emptyList()
        return root
    }

    private fun handler() = Handler(Looper.getMainLooper())

    private fun runAndSettle(block: () -> Unit) {
        block()
        shadowOf(Looper.getMainLooper()).idleFor(
            Duration.ofMillis(TabNeutralizePolicy.FOCUS_SETTLE_DELAY_MS * 3),
        )
    }

    // ─── il caso buono ──────────────────────────────────────────────────────

    @Test
    fun scriveUrlNeutroEConferma_riportaSuccesso() {
        val node = urlBarNode()
        every { node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, any()) } returns true
        every { node.performAction(imeEnterId) } returns true
        var result: Boolean? = null

        TabNeutralizer.neutralize(
            rootProvider = { rootFinding(node) },
            configs = listOf(config()),
            handler = handler(),
        ) { result = it }

        assertThat(result).isTrue()
        // L'ordine conta: scrivere senza confermare lascia la scheda dov'era.
        verifyOrder {
            node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, any())
            node.performAction(imeEnterId)
        }
    }

    @Test
    fun scriveEsattamenteAboutBlank() {
        val node = urlBarNode()
        val written = mutableListOf<Bundle>()
        every {
            node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, capture(written))
        } returns true
        every { node.performAction(imeEnterId) } returns true

        TabNeutralizer.neutralize({ rootFinding(node) }, listOf(config()), handler()) {}

        val value = written.first().getCharSequence(
            AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
        )
        assertThat(value).isEqualTo(TabNeutralizePolicy.NEUTRAL_URL)
    }

    @Test
    fun nonChiedeIlFocusQuandoLaScritturaDirettaBasta() {
        // Il focus fa comparire la tastiera sopra l'overlay: se non serve, non
        // deve essere chiesto.
        val node = urlBarNode()
        every { node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, any()) } returns true
        every { node.performAction(imeEnterId) } returns true

        TabNeutralizer.neutralize({ rootFinding(node) }, listOf(config()), handler()) {}

        verify(exactly = 0) { node.performAction(AccessibilityNodeInfo.ACTION_FOCUS) }
    }

    // ─── fallimenti: devono degradare, non appendersi ───────────────────────

    @Test
    fun commitRifiutato_ripristinaIlTestoOriginale() {
        // Senza ripristino la barra mostrerebbe about:blank su una pagina che
        // e' ancora quella bloccata — e al rientro BrowserUrlDetector
        // leggerebbe about:blank da una scheda in realta' sul dominio bloccato.
        val node = urlBarNode(focused = true, text = "reddit.com/r/all")
        val written = mutableListOf<Bundle>()
        every {
            node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, capture(written))
        } returns true
        every { node.performAction(imeEnterId) } returns false
        var result: Boolean? = null

        TabNeutralizer.neutralize({ rootFinding(node) }, listOf(config()), handler()) { result = it }

        assertThat(result).isFalse()
        assertThat(written).hasSize(2)
        assertThat(
            written[1].getCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE),
        ).isEqualTo("reddit.com/r/all")
    }

    @Test
    fun setTextRifiutato_riportaFallimentoSenzaConfermare() {
        val node = urlBarNode(focused = true)
        every { node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, any()) } returns false
        var result: Boolean? = null

        TabNeutralizer.neutralize({ rootFinding(node) }, listOf(config()), handler()) { result = it }

        assertThat(result).isFalse()
        verify(exactly = 0) { node.performAction(imeEnterId) }
    }

    @Test
    fun rootNull_riportaFallimento() {
        var result: Boolean? = null
        TabNeutralizer.neutralize({ null }, listOf(config()), handler()) { result = it }
        assertThat(result).isFalse()
    }

    @Test
    fun nessunNodoTrovato_riportaFallimento() {
        var result: Boolean? = null
        TabNeutralizer.neutralize({ rootFindingNothing() }, listOf(config()), handler()) {
            result = it
        }
        assertThat(result).isFalse()
    }

    @Test
    fun rootProviderCheEsplode_riportaFallimentoInveceDiPropagare() {
        // Un'eccezione qui non deve poter mangiare l'enforcement.
        var result: Boolean? = null
        TabNeutralizer.neutralize(
            rootProvider = { throw IllegalStateException("albero non disponibile") },
            configs = listOf(config()),
            handler = handler(),
        ) { result = it }
        assertThat(result).isFalse()
    }

    // ─── selezione del nodo ─────────────────────────────────────────────────

    @Test
    fun configConClearUrlFalse_vieneSaltato() {
        val node = urlBarNode()
        var result: Boolean? = null

        TabNeutralizer.neutralize(
            { rootFinding(node) },
            listOf(config(clearUrl = false)),
            handler(),
        ) { result = it }

        assertThat(result).isFalse()
        verify(exactly = 0) { node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, any()) }
    }

    @Test
    fun nodoInSolaLettura_passaAlConfigSuccessivo() {
        // Su Chrome `:id/origin` (chip del dominio, TextView) matcha prima di
        // `:id/url_bar`: non deve far fallire tutta la neutralizzazione.
        val readOnly = urlBarNode(editable = false, setText = false)
        val writable = urlBarNode()
        every { writable.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, any()) } returns true
        every { writable.performAction(imeEnterId) } returns true

        val root = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { root.findAccessibilityNodeInfosByViewId(":id/origin") } returns listOf(readOnly)
        every { root.findAccessibilityNodeInfosByViewId(":id/url_bar") } returns listOf(writable)
        var result: Boolean? = null

        TabNeutralizer.neutralize(
            { root },
            listOf(config(":id/origin"), config(":id/url_bar")),
            handler(),
        ) { result = it }

        assertThat(result).isTrue()
    }

    // ─── ritento dopo il focus ──────────────────────────────────────────────

    @Test
    fun senzaSetText_chiedeIlFocusERitenta() {
        val first = urlBarNode(setText = false)
        val afterFocus = urlBarNode()
        every { afterFocus.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, any()) } returns true
        every { afterFocus.performAction(imeEnterId) } returns true

        // Il secondo tentativo rilegge un root FRESCO: dopo il focus l'albero
        // e' stato ripubblicato e il nodo espone finalmente SET_TEXT.
        var call = 0
        var result: Boolean? = null
        runAndSettle {
            TabNeutralizer.neutralize(
                rootProvider = { if (call++ == 0) rootFinding(first) else rootFinding(afterFocus) },
                configs = listOf(config()),
                handler = handler(),
            ) { result = it }
        }

        verify { first.performAction(AccessibilityNodeInfo.ACTION_FOCUS) }
        assertThat(result).isTrue()
    }

    @Test
    fun ritentoFallito_siArrendeSenzaCicliInfiniti() {
        val node = urlBarNode(setText = false)
        var attempts = 0
        var result: Boolean? = null

        runAndSettle {
            TabNeutralizer.neutralize(
                rootProvider = { attempts++; rootFinding(node) },
                configs = listOf(config()),
                handler = handler(),
            ) { result = it }
        }

        assertThat(result).isFalse()
        assertThat(attempts).isEqualTo(TabNeutralizePolicy.MAX_ATTEMPTS)
    }
}
