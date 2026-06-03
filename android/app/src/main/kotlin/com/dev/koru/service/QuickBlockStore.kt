package com.dev.koru.service

import android.os.SystemClock
import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Stato del quick-block / pomodoro persistito su filesystem così da essere
 * leggibile sia dal main process (che scrive in [QuickBlockManager]) sia
 * dal processo `:accessibility` (dove vive [KoruAccessibilityService] e
 * serve sapere se bloccare le app non-whitelisted).
 *
 * Companion object e static var non sono condivise tra processi Android:
 * ogni processo ha la sua JVM con la propria istanza.
 *
 * ARCH-03/SEC-09: migrato su [FileBackedStore] → scrittura atomica (temp+rename,
 * niente più file torn su `writeText`), cache invalidata su `(mtime,length)` e
 * lock cross-process. Fail-safe su file corrotto: [Snapshot.IDLE] (nessun
 * blocco). NB: per il quick-block "non bloccare" è la direzione benigna — il
 * blocco catch-all è una sessione di focus volontaria, non un cap anti-evasione;
 * un file corrotto al più termina anticipatamente una sessione, non sblocca un
 * limite. La resistenza anti-clock vive in [Snapshot.shouldBlock] (SEC-11).
 */
object QuickBlockStore {
    private const val FILE_NAME = "koru_quick_block_state.json"

    /**
     * @param expiresAt scadenza WALL-clock (System.currentTimeMillis-based).
     * @param expiresAtElapsed scadenza MONOTONICA (SystemClock.elapsedRealtime,
     *   non riavvolgibile). `0` = snapshot legacy senza il campo (scritto prima
     *   di SEC-11) → [shouldBlock] cade sul comportamento wall-only.
     */
    data class Snapshot(
        val isActive: Boolean,
        val isPomodoroMode: Boolean,
        val isBreakPhase: Boolean,
        val expiresAt: Long,
        val whitelist: Set<String>,
        val expiresAtElapsed: Long = 0L,
    ) {
        companion object {
            val IDLE = Snapshot(
                isActive = false,
                isPomodoroMode = false,
                isBreakPhase = false,
                expiresAt = 0,
                whitelist = emptySet(),
                expiresAtElapsed = 0,
            )
        }

        /**
         * L'app [packageName] deve essere bloccata in base a questo snapshot?
         * Ritorna false se nessun timer è attivo, se siamo in break phase,
         * se il timer è scaduto, o se l'app è nella whitelist.
         *
         * SEC-11 — scadenza a DUE orologi (mirror di [BypassEntry.isActive]).
         * Prima la scadenza era solo wall-clock: spostando l'orologio in AVANTI
         * la sessione di focus finiva PRIMA (evasione). Ora, quando lo snapshot
         * porta entrambi gli orologi ([expiresAtElapsed] > 0), consideriamo la
         * sessione scaduta SOLO se ENTRAMBI gli orologi la danno per passata:
         * - un salto WALL in avanti da solo NON termina la sessione (il
         *   monotonico, non falsificabile in avanti, non è ancora scaduto) →
         *   direzione fail-secure scelta: NON finire prima;
         * - un salto WALL indietro non estende all'infinito perché il timer
         *   reale di [QuickBlockManager] (basato sul tempo reale) scade comunque
         *   e azzera lo snapshot; questo guard copre solo il path di lettura
         *   cross-process del `:accessibility`.
         *
         * Snapshot legacy (senza [expiresAtElapsed], = 0): non possiamo
         * incrociare i clock → manteniamo il comportamento wall-only storico.
         *
         * Clock iniettabili per i test (default = orologi reali), come
         * [BypassEntry.isActive].
         */
        fun shouldBlock(
            packageName: String,
            nowWall: Long = System.currentTimeMillis(),
            nowElapsed: Long = SystemClock.elapsedRealtime(),
        ): Boolean {
            if (!isSessionActiveNow(nowWall, nowElapsed)) return false
            if (isPomodoroMode && isBreakPhase) return false
            return !whitelist.contains(packageName)
        }

        /**
         * La sessione di focus è IN CORSO e non scaduta — gate package-independent,
         * che IGNORA break phase e whitelist. È la prima metà di [shouldBlock].
         *
         * Serve al `:accessibility` per decidere se OSSERVARE tutte le app
         * (`packageNames = null`): durante un catch-all qualunque app va valutata,
         * e la break phase NON va esclusa qui (la sessione è ancora attiva, l'app
         * verrà ri-bloccata al rientro in work). Escludere la break dalla scelta
         * del watched-set significherebbe ri-restringere/ri-allargare ad ogni
         * transizione work↔break; tenendo il watch-all per tutta la sessione si
         * ricevono solo eventi in più durante il break — l'evaluator non blocca
         * comunque ([shouldBlock] resta false in break).
         */
        fun isSessionActiveNow(
            nowWall: Long = System.currentTimeMillis(),
            nowElapsed: Long = SystemClock.elapsedRealtime(),
        ): Boolean = isActive && !isExpired(nowWall, nowElapsed)

        /// Scaduto? `expiresAt <= 0` ⇒ mai (nessuna scadenza impostata). Con
        /// entrambi gli orologi presenti ⇒ richiede che ENTRAMBI siano passati
        /// (AND fail-secure: non finire prima). Snapshot legacy (elapsed = 0) ⇒
        /// solo wall (comportamento storico).
        private fun isExpired(nowWall: Long, nowElapsed: Long): Boolean {
            if (expiresAt <= 0L) return false
            val wallPast = nowWall >= expiresAt
            if (expiresAtElapsed <= 0L) return wallPast // legacy: wall-only
            val elapsedPast = nowElapsed >= expiresAtElapsed
            return wallPast && elapsedPast
        }
    }

    private val store = FileBackedStore(
        fileName = FILE_NAME,
        codec = object : FileBackedStore.Codec<Snapshot> {
            override fun serialize(value: Snapshot): String =
                JSONObject().apply {
                    put("isActive", value.isActive)
                    put("isPomodoroMode", value.isPomodoroMode)
                    put("isBreakPhase", value.isBreakPhase)
                    put("expiresAt", value.expiresAt)
                    put("expiresAtElapsed", value.expiresAtElapsed)
                    put("whitelist", JSONArray(value.whitelist.toList()))
                }.toString()

            override fun deserialize(raw: String): Snapshot {
                val json = JSONObject(raw)
                val arr = json.optJSONArray("whitelist")
                val whitelist = mutableSetOf<String>()
                if (arr != null) {
                    for (i in 0 until arr.length()) whitelist.add(arr.getString(i))
                }
                return Snapshot(
                    isActive = json.optBoolean("isActive", false),
                    isPomodoroMode = json.optBoolean("isPomodoroMode", false),
                    isBreakPhase = json.optBoolean("isBreakPhase", false),
                    expiresAt = json.optLong("expiresAt", 0L),
                    // SEC-11: assente negli snapshot legacy → 0 ⇒ wall-only.
                    expiresAtElapsed = json.optLong("expiresAtElapsed", 0L),
                    whitelist = whitelist,
                )
            }
        },
        corruptFallback = { Snapshot.IDLE },
    )

    /// Salva (sovrascrittura atomica) lo snapshot. Ritorna `true` se la
    /// scrittura è andata a buon fine — [QuickBlockManager] propaga l'esito
    /// (CR-09: lo stato di focus è enforcement-affecting).
    fun save(context: Context, snapshot: Snapshot): Boolean = store.write(context, snapshot)

    fun read(context: Context): Snapshot = store.read(context)

    fun clear(context: Context): Boolean = save(context, Snapshot.IDLE)

    // ---------------- test hooks ----------------

    /// Svuota la cache di processo (simula un secondo processo). Solo test.
    internal fun invalidateCacheForTest() = store.invalidateCacheForTest()
}
