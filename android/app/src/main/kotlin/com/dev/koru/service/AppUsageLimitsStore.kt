package com.dev.koru.service

import android.content.Context
import org.json.JSONObject

/**
 * Persistenza cross-process dei limiti giornalieri per-app. Scritto dal main
 * process via MethodChannel, letto da [KoruAccessibilityService] nel processo
 * `:accessibility`.
 *
 * File: `filesDir/koru_app_limits.json`. Lo schema supporta due formati:
 *
 * - **Legacy** (`{"com.pkg": 30}`): l'integer è il cap in minuti; il flag
 *   `strict` viene assunto `true` (interpretazione conservativa: l'utente
 *   aveva impostato un limite, lo trattiamo come hard cap finché non lo
 *   modifica esplicitamente).
 * - **Esteso** (`{"com.pkg": {"minutes": 30, "strict": true,
 *   "challengeLock": true}}`): formato canonico, scritto da `save()`.
 *
 * `strict=true` ⇒ il blocco USAGE_LIMIT non permette "Open anyway".
 * `strict=false` ⇒ progressive friction (vedi [BypassCountStore]).
 *
 * `challengeLock=true` ⇒ due gate, entrambi sulla sola direzione che INDEBOLISCE:
 * indebolire il limite dalle Impostazioni (alzare i minuti, toglierlo,
 * spegnere lo strict) richiede la sfida di sblocco, e a cap raggiunto anche
 * l'"Open anyway" la richiede. Il default è `true` — chi imposta un cap sta
 * chiedendo attrito, non un pulsante.
 *
 * NOTA sul contratto di canale: un campo aggiunto qui NON basta. Anche
 * `LimitsCallHandler.parseLimitEntry` deve leggerlo, altrimenti scarta le key
 * sconosciute e il flag evapora a ogni salvataggio, senza errori e senza test
 * rossi.
 *
 * ARCH-03/SEC-09: migrato su [FileBackedStore]. Prima la `save` usava un plain
 * `writeText` (SEC-09): un crash a metà scrittura lasciava un file torn → tutti
 * i cap giornalieri sparivano (fail-OPEN, l'app capata si sbloccava). Ora la
 * scrittura è atomica (temp+rename) e c'è il lock cross-process. La cache è
 * invalidata su `(mtime,length)` (la `length` cattura due scritture nello stesso
 * secondo che `mtime` a 1s mancherebbe).
 *
 * Fail-secure su file CORROTTO: `corruptFallback` ritorna gli ULTIMI cap noti
 * dalla cache (non una mappa vuota) — un parse error non deve azzerare i limiti,
 * altrimenti basterebbe corrompere il file per sbloccare tutto. Se non c'è
 * nemmeno una cache (primo avvio col file già corrotto) cadiamo su mappa vuota:
 * non c'è uno stato precedente da preservare.
 */
object AppUsageLimitsStore {
    private const val FILE_NAME = "koru_app_limits.json"

    /// Limit config per un singolo package. `minutes <= 0` significa nessun
    /// limite attivo (lo store filtra questi entries via [save]).
    ///
    /// [challengeLock] ha un DEFAULT non per pigrizia ma per compatibilità: è
    /// costruito posizionalmente in una ventina di punti nei test, e senza
    /// default nessuno di quelli compilerebbe più.
    data class LimitEntry(
        val minutes: Int,
        val strict: Boolean,
        val challengeLock: Boolean = true,
    )

    private val store = FileBackedStore(
        fileName = FILE_NAME,
        codec = object : FileBackedStore.Codec<Map<String, LimitEntry>> {
            override fun serialize(value: Map<String, LimitEntry>): String {
                val json = JSONObject()
                for ((k, v) in value) {
                    if (v.minutes <= 0) continue
                    json.put(
                        k,
                        JSONObject().apply {
                            put("minutes", v.minutes)
                            put("strict", v.strict)
                            put("challengeLock", v.challengeLock)
                        },
                    )
                }
                return json.toString()
            }

            override fun deserialize(raw: String): Map<String, LimitEntry> {
                val json = JSONObject(raw)
                val out = mutableMapOf<String, LimitEntry>()
                val keys = json.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    val entry = parseEntry(json.opt(k)) ?: continue
                    if (entry.minutes > 0) out[k] = entry
                }
                return out.toMap()
            }
        },
        // SEC-09 fail-secure: file corrotto ⇒ tieni gli ultimi cap noti; se non
        // c'è cache (null) ⇒ mappa vuota (nessuno stato precedente).
        corruptFallback = { lastCached -> lastCached ?: emptyMap() },
    )

    fun read(context: Context): Map<String, LimitEntry> = store.read(context)

    /// Parsa un singolo entry tollerando il formato legacy. Ritorna null se
    /// il valore è inutilizzabile.
    private fun parseEntry(raw: Any?): LimitEntry? = when (raw) {
        is Number -> LimitEntry(minutes = raw.toInt(), strict = true, challengeLock = true)
        is JSONObject -> {
            val m = raw.optInt("minutes", 0)
            // `strict` default true: per limiti già esistenti senza il
            // campo, hard cap è il comportamento più sicuro. L'utente
            // può sempre modificarlo dal picker.
            val s = raw.optBoolean("strict", true)
            // Stessa logica per `challengeLock`: un limite salvato prima che il
            // campo esistesse era stato messo da qualcuno che voleva attrito,
            // quindi il default conservativo è "protetto".
            val c = raw.optBoolean("challengeLock", true)
            LimitEntry(minutes = m, strict = s, challengeLock = c)
        }
        else -> null
    }

    /// Salva (sovrascrittura atomica) la mappa dei limiti. Gli entry con
    /// `minutes <= 0` sono filtrati dal codec. Ritorna `true` se la scrittura
    /// è andata a buon fine — i chiamanti che portano stato di enforcement
    /// possono propagare l'errore (CR-09).
    fun save(context: Context, limits: Map<String, LimitEntry>): Boolean =
        store.write(context, limits.filter { it.value.minutes > 0 })

    fun limitMinutesFor(context: Context, packageName: String): Int =
        read(context)[packageName]?.minutes ?: 0

    fun isStrictFor(context: Context, packageName: String): Boolean =
        read(context)[packageName]?.strict ?: true

    /// `true` se il bypass a cap raggiunto per [packageName] richiede la sfida
    /// di sblocco. Default `true` anche per un package senza limite: il
    /// chiamante interroga questo solo dopo aver stabilito che un cap c'è.
    fun isChallengeLockedFor(context: Context, packageName: String): Boolean =
        read(context)[packageName]?.challengeLock ?: true

    fun entryFor(context: Context, packageName: String): LimitEntry? =
        read(context)[packageName]

    // ---------------- test hooks ----------------

    /// Svuota la cache di processo (simula un secondo processo). Solo test.
    internal fun invalidateCacheForTest() = store.invalidateCacheForTest()

    /// Valore attualmente in cache (`null` se mai caricato). Solo test.
    internal fun cachedDataForTest(): Map<String, LimitEntry>? = store.cachedDataForTest()
}
