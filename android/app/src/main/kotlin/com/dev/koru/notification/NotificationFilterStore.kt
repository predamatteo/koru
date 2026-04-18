package com.dev.koru.notification

import android.content.Context
import android.util.Log
import java.io.File
import org.json.JSONArray

/**
 * Set di package silenziati (cross-process, file-based): letto dal
 * [KoruNotificationListenerService] a ogni notifica posted, scritto
 * dal main process via MethodChannel.
 *
 * File: `filesDir/koru_notification_filters.json`
 * Formato: `["com.instagram.android", "com.facebook.katana", ...]`
 */
object NotificationFilterStore {
    private const val TAG = "NotificationFilterStore"
    private const val FILE_NAME = "koru_notification_filters.json"

    fun read(context: Context): Set<String> {
        return try {
            val file = File(context.filesDir, FILE_NAME)
            if (!file.exists()) return emptySet()
            val arr = JSONArray(file.readText())
            val out = mutableSetOf<String>()
            for (i in 0 until arr.length()) {
                out.add(arr.getString(i))
            }
            out
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read silenced set", e)
            emptySet()
        }
    }

    fun save(context: Context, silenced: Set<String>) {
        try {
            val file = File(context.filesDir, FILE_NAME)
            val arr = JSONArray(silenced.toList())
            file.writeText(arr.toString())
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save silenced set", e)
        }
    }

    fun isSilenced(context: Context, packageName: String): Boolean =
        read(context).contains(packageName)
}
