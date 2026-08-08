package com.dev.koru.browser

import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.view.accessibility.AccessibilityNodeInfo
import com.dev.koru.diagnostics.BlackBox

/**
 * Side-effect di [TabNeutralizePolicy]: porta la scheda corrente del browser su
 * [TabNeutralizePolicy.NEUTRAL_URL] scrivendo nella barra degli indirizzi.
 *
 * Il "perche'" sta tutto in [TabNeutralizePolicy]; qui c'e' solo il come.
 *
 * ## Contratto col chiamante
 * - **Va invocato PRIMA di andare in HOME.** Una volta che il browser e' in
 *   background il suo albero accessibility non e' piu' raggiungibile e ogni
 *   azione sui nodi fallisce silenziosamente.
 * - `onDone` viene chiamata **sempre ed esattamente una volta**, sul thread del
 *   [Handler] passato. Il chiamante ci appende il `performGoHomeForBlock`:
 *   se questa classe non chiamasse mai `onDone`, il blocco non verrebbe
 *   applicato affatto. Da qui il tetto [TabNeutralizePolicy.MAX_ATTEMPTS] e i
 *   `try/catch` totali — un'eccezione qui dentro non deve poter mangiare
 *   l'enforcement.
 *
 * ## Nodi e recycle
 * Il root viene richiesto tramite [rootProvider] a OGNI tentativo (dopo un
 * focus l'albero e' ripubblicato, quello vecchio e' stantio) e recyclato qui su
 * API < 33 — il chiamante non deve passare un nodo che sta gia' gestendo lui.
 * Vale lo stesso per i nodi restituiti da [UrlBarNodeFinder.find], di cui il
 * caller e' proprietario per contratto.
 */
object TabNeutralizer {

    private const val BB_TAG = "WEBSITE"

    /**
     * Prova a portare la scheda su una pagina neutra.
     *
     * @param rootProvider fornisce un root FRESCO dell'active window ad ogni
     *   chiamata (tipicamente `{ service.rootInActiveWindow }`).
     * @param configs i [BrowserConfig] del package bloccato. Vengono provati in
     *   ordine e quelli con `clearUrl = false` sono saltati.
     * @param handler handler su cui schedulare il ritento dopo il focus e su cui
     *   verra' invocata `onDone`.
     * @param sdkInt iniettabile per i test; in produzione [Build.VERSION.SDK_INT].
     * @param onDone `true` se la scheda e' stata effettivamente navigata via.
     */
    fun neutralize(
        rootProvider: () -> AccessibilityNodeInfo?,
        configs: List<BrowserConfig>,
        handler: Handler,
        sdkInt: Int = Build.VERSION.SDK_INT,
        onDone: (Boolean) -> Unit,
    ) {
        runAttempt(0, rootProvider, configs, handler, sdkInt, onDone)
    }

    private fun runAttempt(
        attempt: Int,
        rootProvider: () -> AccessibilityNodeInfo?,
        configs: List<BrowserConfig>,
        handler: Handler,
        sdkInt: Int,
        onDone: (Boolean) -> Unit,
    ) {
        val outcome = try {
            attemptOnce(attempt, rootProvider, configs, sdkInt)
        } catch (t: Throwable) {
            // Fail-safe: qualunque cosa vada storta nell'albero accessibility,
            // il blocco deve comunque essere applicato.
            BlackBox.log(BB_TAG, "neutralize attempt=$attempt eccezione=${t.javaClass.simpleName}")
            Outcome.GIVE_UP
        }
        when (outcome) {
            Outcome.DONE -> onDone(true)
            Outcome.GIVE_UP -> onDone(false)
            Outcome.RETRY_AFTER_FOCUS -> handler.postDelayed(
                { runAttempt(attempt + 1, rootProvider, configs, handler, sdkInt, onDone) },
                TabNeutralizePolicy.FOCUS_SETTLE_DELAY_MS,
            )
        }
    }

    private enum class Outcome { DONE, RETRY_AFTER_FOCUS, GIVE_UP }

    private fun attemptOnce(
        attempt: Int,
        rootProvider: () -> AccessibilityNodeInfo?,
        configs: List<BrowserConfig>,
        sdkInt: Int,
    ): Outcome {
        val root = rootProvider() ?: run {
            BlackBox.log(BB_TAG, "neutralize attempt=$attempt root=null")
            return Outcome.GIVE_UP
        }
        try {
            for (config in configs) {
                if (!config.clearUrl) continue
                val node = UrlBarNodeFinder.find(root, config) ?: continue
                try {
                    val result = handleNode(attempt, node, config, sdkInt)
                    if (result != null) return result
                } finally {
                    recycle(node)
                }
            }
        } finally {
            recycle(root)
        }
        BlackBox.log(BB_TAG, "neutralize attempt=$attempt nessun nodo scrivibile (configs=${configs.size})")
        return Outcome.GIVE_UP
    }

    /**
     * Esito per un singolo nodo candidato, o `null` per "questo nodo non e'
     * quello giusto, prova il config successivo" (tipico del chip `:id/origin`
     * di Chrome, che matcha ma e' in sola lettura).
     */
    private fun handleNode(
        attempt: Int,
        node: AccessibilityNodeInfo,
        config: BrowserConfig,
        sdkInt: Int,
    ): Outcome? {
        val focusable = node.isFocusable
        val focused = node.isFocused
        val step = TabNeutralizePolicy.firstStep(
            attempt = attempt,
            sdkInt = sdkInt,
            clearUrlAllowed = config.clearUrl,
            nodeEditable = node.isEditable,
            supportsSetText = supportsAction(node, AccessibilityNodeInfo.ACTION_SET_TEXT),
            nodeFocusable = focusable,
            nodeFocused = focused,
        )
        return when (step) {
            TabNeutralizePolicy.Step.UNSUPPORTED -> null

            TabNeutralizePolicy.Step.FOCUS_THEN_RETRY -> {
                node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                Outcome.RETRY_AFTER_FOCUS
            }

            TabNeutralizePolicy.Step.WRITE_AND_COMMIT -> {
                if (writeAndCommit(node)) {
                    BlackBox.log(BB_TAG, "neutralize OK via ${config.viewId} (attempt=$attempt)")
                    return Outcome.DONE
                }
                val next = TabNeutralizePolicy.stepAfterFailedCommit(attempt, focusable, focused)
                if (next == TabNeutralizePolicy.Step.FOCUS_THEN_RETRY) {
                    node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                    Outcome.RETRY_AFTER_FOCUS
                } else {
                    BlackBox.log(BB_TAG, "neutralize commit rifiutato su ${config.viewId} (attempt=$attempt)")
                    Outcome.GIVE_UP
                }
            }
        }
    }

    /**
     * Scrive l'URL neutro e prova a confermarlo.
     *
     * Se la conferma viene rifiutata **ripristiniamo il testo originale**: senza
     * questo la barra resterebbe a mostrare `about:blank` mentre la pagina e'
     * ancora quella bloccata, cioe' uno stato che mente all'utente e che al
     * rientro nel browser confonderebbe anche la nostra stessa
     * [BrowserUrlDetector] (leggerebbe `about:blank` da un nodo di una scheda
     * che sta invece ancora sul dominio bloccato → mancato blocco).
     */
    private fun writeAndCommit(node: AccessibilityNodeInfo): Boolean {
        val original = node.text?.toString()
        if (!setText(node, TabNeutralizePolicy.NEUTRAL_URL)) return false
        if (commitWithImeEnter(node)) return true
        if (original != null) setText(node, original)
        return false
    }

    private fun setText(node: AccessibilityNodeInfo, value: String): Boolean {
        val args = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, value)
        }
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    /**
     * `ACTION_IME_ENTER` e' il "premi Vai sulla tastiera" del framework: e'
     * l'unico modo pubblico per far navigare la barra degli indirizzi. Esiste
     * solo da API 30 — vedi [TabNeutralizePolicy.MIN_SDK_FOR_COMMIT]. La guard
     * usa [Build.VERSION.SDK_INT] direttamente (e non l'`sdkInt` iniettato)
     * perche' qui la domanda non e' "cosa decidiamo" ma "questa API esiste
     * davvero su questo device".
     */
    private fun commitWithImeEnter(node: AccessibilityNodeInfo): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            node.performAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_IME_ENTER.id)
        } else {
            false
        }

    /**
     * Usa `actionList` e non il vecchio `actions`: quest'ultimo e' deprecato ed
     * espone solo la bitmask legacy, mentre le barre degli indirizzi Compose
     * (Firefox recenti) pubblicano le proprie azioni unicamente nella lista.
     */
    private fun supportsAction(node: AccessibilityNodeInfo, action: Int): Boolean =
        node.actionList?.any { it.id == action } == true

    private fun recycle(node: AccessibilityNodeInfo) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            try { node.recycle() } catch (_: Throwable) {}
        }
    }
}
