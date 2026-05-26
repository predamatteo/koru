package com.dev.koru.notification

import android.content.Context
import com.dev.koru.service.FileBackedStore
import org.json.JSONArray

/**
 * Set di package silenziati (cross-process, file-based): letto dal
 * [KoruNotificationListenerService] a ogni notifica posted, scritto
 * dal main process via MethodChannel.
 *
 * File: `filesDir/koru_notification_filters.json`
 * Formato: `["com.instagram.android", "com.facebook.katana", ...]`
 *
 * ARCH-03/SEC-09: migrato su [FileBackedStore] → scrittura atomica (temp+rename,
 * niente più file torn su `writeText`), cache invalidata su `(mtime,length)` e
 * lock cross-process. Fail-safe su file corrotto: set vuoto (nessun filtro;
 * direzione benigna — al più una notifica non viene silenziata, non è uno stato
 * di enforcement che blocca l'utente).
 */
object NotificationFilterStore {
    private const val FILE_NAME = "koru_notification_filters.json"

    private val store = FileBackedStore(
        fileName = FILE_NAME,
        codec = object : FileBackedStore.Codec<Set<String>> {
            override fun serialize(value: Set<String>): String =
                JSONArray(value.toList()).toString()

            override fun deserialize(raw: String): Set<String> {
                val arr = JSONArray(raw)
                val out = mutableSetOf<String>()
                for (i in 0 until arr.length()) out.add(arr.getString(i))
                return out
            }
        },
        corruptFallback = { emptySet() }, // direzione benigna: nessun filtro
    )

    fun read(context: Context): Set<String> = store.read(context)

    fun save(context: Context, silenced: Set<String>): Boolean = store.write(context, silenced)

    fun isSilenced(context: Context, packageName: String): Boolean =
        read(context).contains(packageName)
}
