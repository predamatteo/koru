package com.dev.koru.diagnostics

import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import android.os.Process
import android.os.SystemClock
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Scatola nera persistente: log append-only su file che SOPRAVVIVE al kill del
 * processo. Pensata per diagnosticare freeze / cold-start intermittenti che i
 * log effimeri di `adb logcat` non possono catturare a posteriori (buffer
 * circolare + serve un PC attaccato nel momento esatto).
 *
 * Proprieta' di progetto:
 *  - **I/O su un singolo [HandlerThread] dedicato.** Il chiamante (main thread,
 *    callback dell'accessibility service) paga solo un format leggero + un
 *    `post`; la scrittura su disco avviene sul worker. Cruciale: scrivere su
 *    disco dal main thread sarebbe ESSO STESSO una fonte di jank — proprio cio'
 *    che stiamo cercando.
 *  - **Ring buffer.** Il file e' capato a [MAX_BYTES]; al superamento ruota su
 *    un singolo backup `.1`. Due file x cap = uso disco bounded e prevedibile.
 *  - **Release-safe.** NON e' gated su `BuildConfig.DEBUG`: deve funzionare
 *    sull'APK installato, dove il problema avviene davvero.
 *  - **Non-crash.** Ogni I/O e' in try/catch: un guasto del logging non deve
 *    MAI abbattere l'app.
 *
 * File: `<getExternalFilesDir>/koru_blackbox.log`, recuperabile senza root con
 * `adb pull /sdcard/Android/data/com.dev.koru/files/koru_blackbox.log`.
 * Fallback su `filesDir` interno se l'external non e' montato (in quel caso
 * serve `adb exec-out run-as com.dev.koru cat files/koru_blackbox.log`, ok solo
 * su build debuggable).
 */
object BlackBox {
    private const val TAG = "BlackBox"
    private const val FILE_NAME = "koru_blackbox.log"
    private const val MAX_BYTES = 512L * 1024L // 512KB per file, 1 backup

    @Volatile
    private var enabled = true

    @Volatile
    private var logFile: File? = null

    @Volatile
    private var backupFile: File? = null

    /// Owned ESCLUSIVAMENTE dal worker thread (init lo inizializza via post):
    /// nessuna sincronizzazione necessaria.
    private var currentBytes = 0L

    private val worker: Handler by lazy {
        val ht = HandlerThread("koru-blackbox").apply { start() }
        Handler(ht.looper)
    }

    /// `SimpleDateFormat` NON e' thread-safe: vive e si usa SOLO sul worker.
    private val fmt by lazy { SimpleDateFormat("MM-dd HH:mm:ss.SSS", Locale.US) }

    /**
     * Idempotente. Risolve il file (external files dir, fallback interno) e
     * scrive un header di sessione. Va chiamata il prima possibile nel ciclo di
     * vita del processo (vedi `KoruApplication.onCreate`) cosi' il marker di
     * cold-start e' la prima riga di ogni nuova sessione di processo.
     */
    fun init(context: Context) {
        if (logFile != null) return
        val dir = try {
            context.getExternalFilesDir(null) ?: context.filesDir
        } catch (e: Exception) {
            context.filesDir
        }
        backupFile = File(dir, "$FILE_NAME.1")
        val f = File(dir, FILE_NAME)
        logFile = f
        val pid = Process.myPid()
        try {
            worker.post {
                currentBytes = if (f.exists()) f.length() else 0L
                writeLine(
                    System.currentTimeMillis(),
                    SystemClock.uptimeMillis(),
                    Process.myTid(),
                    "INIT",
                    "===== BlackBox attach pid=$pid file=${f.absolutePath} existing=${currentBytes}B =====",
                )
            }
        } catch (_: Throwable) {
            // worker non avviabile: degradiamo silenziosamente.
        }
    }

    fun setEnabled(value: Boolean) {
        enabled = value
    }

    fun path(): String? = logFile?.absolutePath

    /**
     * Accoda una riga. Cheap sul thread chiamante: cattura timestamp/tid e fa un
     * `post` sul worker; il format della data e la scrittura avvengono la'.
     */
    fun log(tag: String, msg: String) {
        if (!enabled) return
        val wall = System.currentTimeMillis()
        val up = SystemClock.uptimeMillis()
        val tid = Process.myTid()
        try {
            worker.post { writeLine(wall, up, tid, tag, msg) }
        } catch (_: Throwable) {
            // worker non disponibile (init mai chiamata?): fallback logcat.
            Log.d(TAG, "[$tag] $msg")
        }
    }

    private fun writeLine(wall: Long, up: Long, tid: Int, tag: String, msg: String) {
        val f = logFile ?: return
        val line = "${fmt.format(Date(wall))} +${up}ms t$tid [$tag] $msg\n"
        try {
            val bytes = line.toByteArray() // UTF-8
            rotateIfNeeded(bytes.size.toLong())
            f.appendText(line)
            currentBytes += bytes.size
        } catch (_: Throwable) {
            // disco pieno / permessi / file sparito: non propagare mai.
        }
    }

    /// Ruota quando la prossima riga sforerebbe il cap: rinomina il file
    /// corrente su `.1` (sovrascrivendo il backup precedente) e riparte da 0.
    private fun rotateIfNeeded(incoming: Long) {
        if (currentBytes + incoming <= MAX_BYTES) return
        val f = logFile ?: return
        val b = backupFile ?: return
        try {
            if (b.exists()) b.delete()
            if (!f.renameTo(b)) f.writeText("") // fallback: tronca in place
        } catch (_: Throwable) {
            try {
                f.writeText("")
            } catch (_: Throwable) {
            }
        }
        currentBytes = 0L
    }
}
