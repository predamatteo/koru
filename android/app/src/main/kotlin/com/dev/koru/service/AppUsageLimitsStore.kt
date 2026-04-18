package com.dev.koru.service

import android.content.Context
import android.util.Log
import java.io.File
import org.json.JSONObject

/**
 * Persistenza cross-process dei limiti giornalieri per-app (packageName →
 * minuti/giorno). Usato come QuickBlockStore: scritto dal main process via
 * MethodChannel, letto da [KoruAccessibilityService] nel processo
 * `:accessibility`.
 *
 * File: `filesDir/koru_app_limits.json`. Formato: `{"com.pkg": 30, ...}`.
 * Valore 0 o assente = nessun limite.
 */
object AppUsageLimitsStore {
    private const val TAG = "AppUsageLimitsStore"
    private const val FILE_NAME = "koru_app_limits.json"

    fun read(context: Context): Map<String, Int> {
        return try {
            val file = File(context.filesDir, FILE_NAME)
            if (!file.exists()) return emptyMap()
            val json = JSONObject(file.readText())
            val out = mutableMapOf<String, Int>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                val v = json.optInt(k, 0)
                if (v > 0) out[k] = v
            }
            out
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read limits, returning empty", e)
            emptyMap()
        }
    }

    fun save(context: Context, limits: Map<String, Int>) {
        try {
            val file = File(context.filesDir, FILE_NAME)
            val json = JSONObject()
            for ((k, v) in limits) {
                if (v > 0) json.put(k, v)
            }
            file.writeText(json.toString())
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save limits", e)
        }
    }

    fun limitMinutesFor(context: Context, packageName: String): Int =
        read(context)[packageName] ?: 0
}
