package com.dev.koru.service

import android.content.Context
import android.util.Log
import java.io.File
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
 */
object QuickBlockStore {
    private const val TAG = "QuickBlockStore"
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

    fun save(context: Context, snapshot: Snapshot) {
        try {
            val file = File(context.filesDir, FILE_NAME)
            val json = JSONObject().apply {
                put("isActive", snapshot.isActive)
                put("isPomodoroMode", snapshot.isPomodoroMode)
                put("isBreakPhase", snapshot.isBreakPhase)
                put("expiresAt", snapshot.expiresAt)
                put("whitelist", JSONArray(snapshot.whitelist.toList()))
            }
            file.writeText(json.toString())
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save snapshot", e)
        }
    }

    fun read(context: Context): Snapshot {
        return try {
            val file = File(context.filesDir, FILE_NAME)
            if (!file.exists()) return Snapshot.IDLE
            val json = JSONObject(file.readText())
            val arr = json.optJSONArray("whitelist")
            val whitelist = mutableSetOf<String>()
            if (arr != null) {
                for (i in 0 until arr.length()) whitelist.add(arr.getString(i))
            }
            Snapshot(
                isActive = json.optBoolean("isActive", false),
                isPomodoroMode = json.optBoolean("isPomodoroMode", false),
                isBreakPhase = json.optBoolean("isBreakPhase", false),
                expiresAt = json.optLong("expiresAt", 0L),
                whitelist = whitelist,
            )
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read snapshot, returning IDLE", e)
            Snapshot.IDLE
        }
    }

    fun clear(context: Context) = save(context, Snapshot.IDLE)
}
