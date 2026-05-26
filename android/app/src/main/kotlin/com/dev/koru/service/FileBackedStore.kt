package com.dev.koru.service

import android.content.Context
import android.util.Log
import java.io.File
import java.io.RandomAccessFile
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.concurrent.atomic.AtomicReference

/**
 * ARCH-03 — astrazione condivisa per gli store cross-process file-based,
 * modellata sul pattern PROVATO di [BypassStore] (verificato solido da tutti e
 * 3 i reviewer della security review 2026-05-26).
 *
 * Koru gira l'enforcement in due processi (main + `:accessibility`); diversi
 * pezzi di stato (bypass, contatori del cap, focus/quick-block, filtri
 * notifiche) sono letti/scritti da entrambi. `companion object`/static **non**
 * sono condivisi tra processi Android (una JVM per processo), quindi la fonte
 * di verità deve stare su disco. Prima della review questi 5 store avevano 5
 * livelli di robustezza diversi (da [BypassStore] atomico+locked fino a un
 * plain `writeText` senza invalidazione): questa classe centralizza le
 * garanzie del gold standard, così ogni store le eredita.
 *
 * Garanzie (parametrizzate dal [codec] e dal [fileName]):
 * - **Letture** ([read], hot path) cache-based: una `AtomicReference` invalidata
 *   su `(lastModified, length)` del file. `length` oltre a `mtime` perché su FS
 *   con `mtime` a granularità di 1s due scritture nello stesso secondo non
 *   cambierebbero `lastModified`; la lunghezza quasi sempre sì (SEC-09/CR-04).
 *   La read NON prende il file lock: la scrittura atomica garantisce che un
 *   reader veda o il file vecchio intero o il nuovo intero, mai uno torn.
 * - **Mutazioni** ([mutate], [write]) read-modify-write serializzato sia
 *   INTRA-processo (`synchronized(localLock)`) sia CROSS-processo
 *   (`FileChannel.lock` su un sidecar `.lock`). Sotto lock si legge SEMPRE
 *   fresco da disco ([readFresh], NON la cache potenzialmente stale dell'altro
 *   processo) e si scrive ATOMICAMENTE (temp file + rename). Senza il lock
 *   cross-process due processi che scrivono durante l'handoff di morte/rinascita
 *   dell'AccessibilityService farebbero last-writer-wins sull'intero blob.
 * - **Fail-safe su corruzione**: un file torn/illeggibile fa sì che [codec]
 *   `deserialize` lanci; l'astrazione cattura e usa [corruptFallback]. La
 *   DIREZIONE del fallback la sceglie lo store chiamante (es. "mappa vuota" per
 *   i bypass, "tieni gli ultimi cap noti" per i limiti) — vedi i singoli store.
 *
 * `write`/`mutate` ritornano `Boolean` (successo) così i chiamanti che portano
 * stato di enforcement possono propagare il fallimento invece di ingoiarlo
 * (CR-09); gli analytics fire-and-forget possono semplicemente ignorarlo.
 *
 * Nota cache cross-processo: ogni processo ha la PROPRIA cache. Le scritture di
 * un processo non invalidano la cache dell'altro direttamente, ma il check
 * `(mtime,length)` al primo [read] successivo la rileva e ricarica. Questo
 * chiude CR-04 (dove la vecchia cache di [BypassCountStore] non si invalidava
 * MAI → conteggio UI permanentemente stale nel main process).
 *
 * @param fileName nome del file dentro `context.filesDir`.
 * @param codec serializzazione/deserializzazione di [T] ↔ String (tipicamente
 *   JSON). `deserialize` riceve il testo grezzo del file; può lanciare su input
 *   corrotto (l'astrazione lo gestisce).
 * @param corruptFallback valore restituito quando il file è illeggibile/corrotto
 *   o quando `deserialize` lancia. Riceve l'ULTIMO valore in cache di QUESTO
 *   processo (`null` se mai caricato): consente la direzione fail-secure
 *   "mantieni gli ultimi cap noti" (SEC-09) invece di azzerare lo stato a fronte
 *   di un file torn. DEVE comunque essere la direzione fail-secure dello store
 *   (più frizione / mantieni il blocco).
 */
class FileBackedStore<T>(
    private val fileName: String,
    private val codec: Codec<T>,
    private val corruptFallback: (lastCached: T?) -> T,
) {
    private val tmpName = "$fileName.tmp"
    private val lockName = "$fileName.lock"

    /// Serializza/deserializza [T] da/verso la rappresentazione su disco.
    interface Codec<T> {
        fun serialize(value: T): String
        fun deserialize(raw: String): T
    }

    private data class CachedSnapshot<T>(
        val data: T,
        val fileLastModified: Long,
        val fileLength: Long,
    )

    private val cache = AtomicReference<CachedSnapshot<T>?>(null)

    /// Va preso PRIMA del file lock: `FileChannel.lock` lancia
    /// OverlappingFileLockException se lo stesso JVM tenta due lock sovrapposti,
    /// quindi i thread del processo si accodano qui prima di contendere il lock
    /// cross-process.
    private val localLock = Any()

    /// Stato corrente (cache-based, NON prende il file lock). Su cache-hit
    /// `(mtime,length)` ritorna l'istanza cache-ata; altrimenti ricarica da
    /// disco. Su file mancante ritorna `corruptFallback(null)` (stato vuoto); su
    /// file corrotto ritorna `corruptFallback(ultimaCache)` (fail-secure: lo
    /// store può tenere l'ultimo stato noto).
    fun read(context: Context): T {
        val file = File(context.filesDir, fileName)
        val lastModified = file.lastModified() // 0L se il file non esiste
        val length = file.length()
        val current = cache.get()
        if (current != null &&
            current.fileLastModified == lastModified &&
            current.fileLength == length
        ) {
            return current.data
        }
        return loadFromDisk(file, lastModified, length)
    }

    private fun loadFromDisk(file: File, lastModified: Long, length: Long): T {
        if (!file.exists()) {
            // File assente (mai scritto o cancellato): NON è una corruzione →
            // passiamo `null` così il fallback ritorna lo stato fresco/vuoto, e
            // lo mettiamo in cache come "vuoto" per evitare re-stat.
            val empty = corruptFallback(null)
            cache.set(CachedSnapshot(empty, 0L, 0L))
            return empty
        }
        return try {
            val value = codec.deserialize(file.readText())
            cache.set(CachedSnapshot(value, lastModified, length))
            value
        } catch (e: Exception) {
            // File torn/corrotto: passiamo l'ultimo valore in cache così uno
            // store come AppUsageLimitsStore può "tenere gli ultimi cap noti"
            // (SEC-09) invece di azzerarli. NON aggiorniamo la cache (il file è
            // illeggibile): al prossimo read ritentiamo.
            Log.w(TAG, "Failed to read $fileName, returning fallback", e)
            corruptFallback(cache.get()?.data)
        }
    }

    /// Read-modify-write atomico e serializzato cross-process. [transform]
    /// riceve lo stato FRESCO da disco (non la cache) e ritorna il nuovo valore;
    /// se non cambia nulla la scrittura viene saltata (no-op). Ritorna `true`
    /// se la scrittura è andata a buon fine (o se era un no-op), `false` se la
    /// scrittura è fallita → il chiamante può propagare l'errore (CR-09).
    fun mutate(context: Context, transform: (T) -> T): Boolean {
        synchronized(localLock) {
            var ok = true
            withFileLock(context) {
                val current = readFresh(context)
                val updated = transform(current)
                ok = if (updated != current) writeAtomic(context, updated) else true
            }
            return ok
        }
    }

    /// Scrittura incondizionata (sotto lock) di [value]. Ritorna `true` se la
    /// scrittura è riuscita. Usato dagli store che sovrascrivono interamente lo
    /// stato (es. `save`/`clear`), dove non serve leggere prima.
    fun write(context: Context, value: T): Boolean {
        synchronized(localLock) {
            var ok = true
            withFileLock(context) {
                ok = writeAtomic(context, value)
            }
            return ok
        }
    }

    /// Legge SEMPRE da disco (bypassa la cache) e la aggiorna. Usato sotto file
    /// lock, dove dobbiamo vedere le scritture appena fatte dall'altro processo.
    /// Su corruzione ritorna [corruptFallback] (così un RMW riparte da uno stato
    /// fail-secure valido invece di propagare un parse error).
    private fun readFresh(context: Context): T {
        val file = File(context.filesDir, fileName)
        return loadFromDisk(file, file.lastModified(), file.length())
    }

    private fun writeAtomic(context: Context, value: T): Boolean {
        return try {
            val file = File(context.filesDir, fileName)
            val tmp = File(context.filesDir, tmpName)
            val text = codec.serialize(value)
            tmp.writeText(text)
            try {
                Files.move(tmp.toPath(), file.toPath(), StandardCopyOption.REPLACE_EXISTING)
            } catch (e: Exception) {
                // FS senza move/replace (alcuni mount): fallback diretto. Meno
                // atomico ma il file resta valido (writeText scrive tutto).
                file.writeText(text)
                tmp.delete()
            }
            cache.set(CachedSnapshot(value, file.lastModified(), file.length()))
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write $fileName", e)
            false
        }
    }

    /// Lock di file CROSS-PROCESS sul sidecar `.lock`. Serializza i RMW tra
    /// `:accessibility` e main. Best-effort: se il lock non è disponibile (FS
    /// particolare, ambiente di test) degradiamo eseguendo comunque il body —
    /// [localLock] garantisce l'atomicità intra-processo. [body] viene eseguito
    /// ESATTAMENTE una volta in ogni ramo.
    private fun withFileLock(context: Context, body: () -> Unit) {
        val raf = try {
            RandomAccessFile(File(context.filesDir, lockName), "rw")
        } catch (e: Exception) {
            Log.w(TAG, "Cannot open lock file for $fileName, proceeding best-effort", e)
            body()
            return
        }
        raf.use {
            val lock = try {
                it.channel.lock()
            } catch (e: Exception) {
                Log.w(TAG, "Cannot acquire cross-process lock for $fileName, proceeding best-effort", e)
                null
            }
            try {
                body()
            } finally {
                try { lock?.release() } catch (_: Exception) {}
            }
        }
    }

    /// Solo per i test: svuota la cache di questo processo, simulando un secondo
    /// processo che non l'ha ancora popolata. NON tocca il file su disco.
    internal fun invalidateCacheForTest() {
        cache.set(null)
    }

    /// Solo per i test: il valore attualmente in cache di questo processo
    /// (`null` se mai caricato). Usato per asserire che [write]/[mutate]
    /// popolino la cache senza un [read] intermedio.
    internal fun cachedDataForTest(): T? = cache.get()?.data

    companion object {
        private const val TAG = "FileBackedStore"
    }
}
