package com.dev.koru.service

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

    data class Snapshot(
        val isActive: Boolean,
        val isPomodoroMode: Boolean,
        val isBreakPhase: Boolean,
        val expiresAt: Long,
        val whitelist: Set<String>,
    ) {
        companion object {
            val IDLE = Snapshot(
                isActive = false,
                isPomodoroMode = false,
                isBreakPhase = false,
                expiresAt = 0,
                whitelist = emptySet(),
            )
        }

        /**
         * L'app [packageName] deve essere bloccata in base a questo snapshot?
         * Ritorna false se nessun timer è attivo, se siamo in break phase,
         * se il timer è scaduto, o se l'app è nella whitelist.
         */
        fun shouldBlock(packageName: String, now: Long): Boolean {
            if (!isActive) return false
            if (expiresAt in 1..now) return false // expired — safety valve
            if (isPomodoroMode && isBreakPhase) return false
            return !whitelist.contains(packageName)
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
}
