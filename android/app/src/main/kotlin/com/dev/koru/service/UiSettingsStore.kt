package com.dev.koru.service

import android.content.Context
import android.util.Log
import org.json.JSONObject

/**
 * Impostazioni UI **globali** condivise col processo `:accessibility`. Oggi
 * contiene solo il font scelto dall'utente, usato dall'overlay di blocco nativo.
 *
 * Perché uno store dedicato e non [com.dev.koru.overlay.OverlayConfig]:
 * OverlayConfig è per-app-per-profilo (serializzato in `app_profile_relations`),
 * mentre il font è una preferenza globale unica. Metterlo lì significherebbe
 * duplicarlo su ogni relazione e non coprirebbe i default. Hive (dove la
 * preferenza vive lato Flutter) non è leggibile dal processo `:accessibility`.
 *
 * ARCH-03 — su [FileBackedStore] come gli altri store cross-process (pattern di
 * [BypassCountStore]): il main process scrive (via `ProfileMethodChannel.
 * setActiveFontId`), il processo `:accessibility` legge in [OverlayManager].
 *
 * File: `filesDir/koru_ui_settings.json` → `{"activeFontId": 2}`.
 */
object UiSettingsStore {
    private const val TAG = "UiSettingsStore"
    private const val FILE_NAME = "koru_ui_settings.json"
    private const val KEY_FONT_ID = "activeFontId"

    /// id 0 = System font (mirror di `KoruFont.system`, font_catalog.dart).
    const val DEFAULT_FONT_ID = 0

    internal data class State(val activeFontId: Int) {
        companion object {
            val DEFAULT = State(DEFAULT_FONT_ID)
        }
    }

    private val store = FileBackedStore(
        fileName = FILE_NAME,
        codec = object : FileBackedStore.Codec<State> {
            override fun serialize(value: State): String =
                JSONObject().put(KEY_FONT_ID, value.activeFontId).toString()

            override fun deserialize(raw: String): State =
                State(JSONObject(raw).optInt(KEY_FONT_ID, DEFAULT_FONT_ID))
        },
        // File assente/corrotto ⇒ system font. Non è enforcement: il "default"
        // è la direzione giusta (al massimo l'overlay usa il font di sistema).
        corruptFallback = { State.DEFAULT },
    )

    /// Font id corrente (0-4). Read cache-ata, sicura sull'hot path dell'overlay.
    fun activeFontId(context: Context): Int =
        try {
            store.read(context).activeFontId
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read ui settings; default font", e)
            DEFAULT_FONT_ID
        }

    /// Persiste il font scelto (chiamato dal main process al cambio preferenza).
    /// Ritorna true se la scrittura è andata a buon fine.
    fun setActiveFontId(context: Context, fontId: Int): Boolean =
        store.write(context, State(fontId))

    // ---------------- test hooks ----------------

    internal fun invalidateCacheForTest() = store.invalidateCacheForTest()
}
