package com.dev.koru.strictmode

import android.os.SystemClock
import java.security.SecureRandom

/**
 * Sfida a memoria che autorizza un **downgrade della strict-mode mask**, al
 * posto del backdoor code.
 *
 * Perché sta in Kotlin e non in Dart, dove vive la UI del puzzle: il gate di
 * autorizzazione è nativo (SEC-01, [UnblockTokenStore]) e un controllo scritto
 * solo lato Flutter verrebbe — correttamente — ignorato da
 * `setStrictModeOptions`. Se il puzzle deve poter aprire lo strict mode, è il
 * native a dover decidere *qual è* la sequenza e a certificare che sia stata
 * riprodotta.
 *
 * Divisione dei compiti col Dart:
 * - **qui** si sceglie quali caselle della griglia formano la sequenza e in che
 *   ordine ([Spec.sequenceSlots]) — indici astratti, nessuna nozione di icone;
 * - **là** si decide quale simbolo disegnare in ogni casella (famiglie di
 *   glifi confondibili, distrattori) e si valida tocco per tocco per dare
 *   feedback immediato.
 *
 * Il native resta quindi libero da qualsiasi tabella di glifi: non esiste un
 * "contratto dei simboli" cross-runtime da tenere allineato a mano, che è
 * esattamente il tipo di divergenza silenziosa che questo progetto paga cara
 * altrove (vedi il contratto di schema DB).
 *
 * ### Cosa protegge davvero
 *
 * Non protegge il *segreto*: la sequenza è per forza nota al client, che deve
 * disegnarla all'utente. Protegge il **processo**: un token si ottiene solo
 * dopo che una sfida emessa da qui è stata risolta, entro il TTL, una volta
 * sola, e per la mask per cui era stata chiesta. È lo stesso perimetro del
 * backdoor code — che pure è recuperabile via channel (`generateBackdoorCode`).
 *
 * Contro il brute force sulla risposta la difesa non è il rate limit ma il
 * fatto che **ogni verifica fallita brucia la sfida** ([verify] azzera lo
 * stato): indovinare richiede una `start` nuova, e la risposta cambia. Su una
 * griglia da 16 con 5 simboli in ordine sono 16·15·14·13·12 ≈ 5,2·10⁵
 * possibilità, una per tentativo. Il cooldown dopo
 * [MAX_CONSECUTIVE_FAILURES] fallimenti è solo un fastidio aggiuntivo, non
 * la barriera principale.
 *
 * Lo stato vive solo in memoria di processo, come [UnblockTokenStore]: un
 * riavvio invalida sfida e cooldown. È coerente col fatto che la barriera è il
 * puzzle, non l'attesa — e chiudere Koru per saltare 60 secondi di cooldown è
 * uno sforzo maggiore del cooldown stesso.
 *
 * Fuori scope, di proposito: l'**emergency unblock** resta sul backdoor code.
 * È la rete di sicurezza per quando il puzzle non basta (o non si riesce a
 * risolverlo), e ha senso che costi la rotazione settimanale.
 */
object StrictUnlockChallengeStore {

    /// Finestra per memorizzare + ricostruire. Generosa rispetto ai 60s del
    /// token ([UnblockTokenStore.TTL_MS]) perché qui dentro ci sta un'intera
    /// interazione umana, non un round-trip fra due chiamate di channel.
    const val TTL_MS: Long = 180_000L

    /// Verifiche fallite consecutive prima del cooldown. Basso: fallire la
    /// *verifica* (non il singolo tocco, che il Dart gestisce da solo) significa
    /// che il client sta mandando risposte che l'utente non ha prodotto.
    const val MAX_CONSECUTIVE_FAILURES = 5

    const val COOLDOWN_MS: Long = 60_000L

    /// Difficoltà. Non è un `enum` esposto al Dart: i parametri viaggiano nella
    /// [Spec] e il Flutter si limita a disegnare quello che riceve, così la
    /// calibrazione resta una decisione nativa e non c'è un secondo elenco di
    /// livelli da tenere allineato.
    private data class Difficulty(
        val sequenceLength: Int,
        val gridSize: Int,
        val columns: Int,
        val memorizeMs: Int,
    )

    /// Spegnere UNA restrizione: 4 simboli su griglia 3×4.
    private val LOOSEN = Difficulty(sequenceLength = 4, gridSize = 12, columns = 3, memorizeMs = 4_000)

    /// Uscire del tutto dallo strict mode: 5 simboli su griglia 4×4 e un
    /// secondo in meno per guardarli. L'azione più grave costa di più.
    private val EXIT = Difficulty(sequenceLength = 5, gridSize = 16, columns = 4, memorizeMs = 3_000)

    /// La sfida da disegnare. [sequenceSlots] sono indici in `0 until gridSize`,
    /// distinti, **nell'ordine in cui vanno toccati**.
    data class Spec(
        val gridSize: Int,
        val columns: Int,
        val sequenceSlots: List<Int>,
        val memorizeMs: Int,
        val targetMask: Int,
    )

    sealed class StartOutcome {
        data class Issued(val spec: Spec) : StartOutcome()
        data class Cooldown(val remainingMs: Long) : StartOutcome()

        /// La mask richiesta non spegne nulla: non c'è niente da autorizzare.
        /// Alzare le restrizioni non passa mai di qui (resta libero).
        object NotADowngrade : StartOutcome()
    }

    private val secureRandom = SecureRandom()
    private val lock = Any()

    private var answer: List<Int>? = null
    private var targetMask: Int = 0
    private var issuedElapsedMs: Long = 0L
    private var consecutiveFailures: Int = 0
    private var cooldownUntilElapsedMs: Long = 0L

    /// Emette una sfida per il passaggio [oldMask] → [newMask]. Invalida
    /// qualsiasi sfida precedente (una sola viva alla volta).
    fun start(
        oldMask: Int,
        newMask: Int,
        nowElapsedMs: Long = SystemClock.elapsedRealtime(),
        random: java.util.Random = secureRandom,
    ): StartOutcome {
        synchronized(lock) {
            // Stessa condizione di StrictModeMethodChannel.clearsActiveBit:
            // se newMask è un superset di oldMask non si sta spegnendo nulla.
            if ((newMask and oldMask) == oldMask) return StartOutcome.NotADowngrade

            val cooldown = cooldownRemainingLocked(nowElapsedMs)
            if (cooldown > 0L) return StartOutcome.Cooldown(cooldown)

            // "Uscita completa" = la nuova mask non lascia acceso nessun bit.
            // Non basta `newMask == 0`: se un bit non era acceso nemmeno prima,
            // spegnere tutto il resto è comunque un'uscita.
            val difficulty = if ((newMask and oldMask) == 0) EXIT else LOOSEN

            val slots = (0 until difficulty.gridSize).toMutableList()
            java.util.Collections.shuffle(slots, random)
            val sequenceSlots = slots.take(difficulty.sequenceLength)

            answer = sequenceSlots
            targetMask = newMask
            issuedElapsedMs = nowElapsedMs

            return StartOutcome.Issued(
                Spec(
                    gridSize = difficulty.gridSize,
                    columns = difficulty.columns,
                    sequenceSlots = sequenceSlots,
                    memorizeMs = difficulty.memorizeMs,
                    targetMask = newMask,
                ),
            )
        }
    }

    /// Verifica [submitted] contro la sfida in corso. Ritorna la mask
    /// autorizzata (da passare a [UnblockTokenStore.issue] come `boundMask`)
    /// oppure `null` se non c'è sfida viva, è scaduta o la risposta è sbagliata.
    ///
    /// **Qualunque** esito azzera la sfida: giusta perché è monouso, sbagliata
    /// perché è ciò che rende inutile tirare a indovinare (vedi header).
    fun verify(
        submitted: List<Int>,
        nowElapsedMs: Long = SystemClock.elapsedRealtime(),
    ): Int? {
        synchronized(lock) {
            if (cooldownRemainingLocked(nowElapsedMs) > 0L) return null

            val expected = answer
            val mask = targetMask
            val age = nowElapsedMs - issuedElapsedMs
            // La sfida è comunque bruciata: usciamo sempre da qui con lo stato
            // pulito, così nessun ramo può lasciare una risposta riutilizzabile.
            clearChallengeLocked()

            if (expected == null) return null
            if (age < 0L || age > TTL_MS) return null

            if (submitted != expected) {
                consecutiveFailures++
                if (consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
                    cooldownUntilElapsedMs = nowElapsedMs + COOLDOWN_MS
                    consecutiveFailures = 0
                }
                return null
            }

            consecutiveFailures = 0
            return mask
        }
    }

    fun cooldownRemainingMs(nowElapsedMs: Long = SystemClock.elapsedRealtime()): Long =
        synchronized(lock) { cooldownRemainingLocked(nowElapsedMs) }

    /// Butta via sfida, contatore e cooldown. Usata dai test e dopo un unblock
    /// riuscito per non lasciare in giro stato che non serve più.
    fun reset() {
        synchronized(lock) {
            clearChallengeLocked()
            consecutiveFailures = 0
            cooldownUntilElapsedMs = 0L
        }
    }

    private fun cooldownRemainingLocked(nowElapsedMs: Long): Long {
        if (cooldownUntilElapsedMs <= 0L) return 0L
        val remaining = cooldownUntilElapsedMs - nowElapsedMs
        return if (remaining > 0L) {
            remaining
        } else {
            cooldownUntilElapsedMs = 0L
            0L
        }
    }

    private fun clearChallengeLocked() {
        answer = null
        targetMask = 0
        issuedElapsedMs = 0L
    }
}
