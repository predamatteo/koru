package com.dev.koru.service

import android.content.Context
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import org.json.JSONObject

/**
 * Counter giornaliero dei bypass per-package. Persistito su file in modo
 * cross-process: il main process può leggerlo per UI (es. "bypassed N
 * times today"), il processo `:accessibility` lo incrementa quando
 * l'utente conferma il duration picker e lo legge per calcolare la
 * progressive friction (countdown crescente, durate decrescenti).
 *
 * File: `filesDir/koru_bypass_counts.json`.
 * Schema: `{"com.pkg": {"date": "2026-05-05", "count": 3}}`.
 *
 * Il reset è implicito: se la data salvata non corrisponde a oggi,
 * `todayCount` ritorna 0 senza riscrivere il file (la riscrittura avviene
 * al primo `increment` del nuovo giorno). Questo evita scritture inutili
 * nei pull di sola lettura.
 */
object BypassCountStore {
    private const val TAG = "BypassCountStore"
    private const val FILE_NAME = "koru_bypass_counts.json"

    private val dateFormat: SimpleDateFormat
        get() = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    /// Numero di bypass usati oggi per [packageName]. Ritorna 0 se la data
    /// salvata non è oggi (o se nessun entry esiste).
    fun todayCount(context: Context, packageName: String): Int {
        return try {
            val file = File(context.filesDir, FILE_NAME)
            if (!file.exists()) return 0
            val json = JSONObject(file.readText())
            val obj = json.optJSONObject(packageName) ?: return 0
            val date = obj.optString("date", "")
            if (date != todayString()) return 0
            obj.optInt("count", 0)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read bypass count, returning 0", e)
            0
        }
    }

    /// Incrementa il counter di [packageName] e ritorna il nuovo valore.
    /// Se la data salvata non è oggi, riparte da 1.
    fun increment(context: Context, packageName: String): Int {
        return try {
            val file = File(context.filesDir, FILE_NAME)
            val json = if (file.exists()) {
                JSONObject(file.readText())
            } else {
                JSONObject()
            }
            val today = todayString()
            val existing = json.optJSONObject(packageName)
            val newCount = if (existing == null || existing.optString("date") != today) {
                1
            } else {
                existing.optInt("count", 0) + 1
            }
            json.put(packageName, JSONObject().apply {
                put("date", today)
                put("count", newCount)
            })
            file.writeText(json.toString())
            newCount
        } catch (e: Exception) {
            Log.e(TAG, "Failed to increment bypass count", e)
            0
        }
    }

    /// Reset esplicito (utile per debug e per quando l'utente abilita lo
    /// strict mode su un'app — i contatori storici diventano irrilevanti).
    fun reset(context: Context, packageName: String) {
        try {
            val file = File(context.filesDir, FILE_NAME)
            if (!file.exists()) return
            val json = JSONObject(file.readText())
            json.remove(packageName)
            file.writeText(json.toString())
        } catch (e: Exception) {
            Log.w(TAG, "Failed to reset bypass count", e)
        }
    }

    private fun todayString(): String {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return dateFormat.format(Date(cal.timeInMillis))
    }
}
