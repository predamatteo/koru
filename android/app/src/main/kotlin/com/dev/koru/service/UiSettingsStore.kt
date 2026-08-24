package com.dev.koru.service

import android.content.Context
import android.util.Log
import org.json.JSONObject

/**
 * Impostazioni UI **globali** leggibili anche dal motore di enforcement: il
 * font scelto dall'utente (usato dall'overlay di blocco nativo) e
 * l'abilitazione del contatore di reel.
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
 * File: `filesDir/koru_ui_settings.json` →
 * `{"activeFontId": 2, "reelCounterEnabled": true}`.
 */
object UiSettingsStore {
    private const val TAG = "UiSettingsStore"
    private const val FILE_NAME = "koru_ui_settings.json"
    private const val KEY_FONT_ID = "activeFontId"
    private const val KEY_REEL_COUNTER = "reelCounterEnabled"

    /// id 0 = System font (mirror di `KoruFont.system`, font_catalog.dart).
    const val DEFAULT_FONT_ID = 0

    /// Il contatore di reel nasce acceso: è una statistica passiva e la feature
    /// sarebbe invisibile se richiedesse un opt-in esplicito. Chi non la vuole
    /// la spegne da Impostazioni, e quello spegne anche l'osservazione di
    /// Instagram/YouTube (vedi [WatchedPackageCalculator]).
    const val DEFAULT_REEL_COUNTER_ENABLED = true

    internal data class State(
        val activeFontId: Int,
        val reelCounterEnabled: Boolean = DEFAULT_REEL_COUNTER_ENABLED,
    ) {
        companion object {
            val DEFAULT = State(DEFAULT_FONT_ID, DEFAULT_REEL_COUNTER_ENABLED)
        }
    }

    private val store = FileBackedStore(
        fileName = FILE_NAME,
        codec = object : FileBackedStore.Codec<State> {
            override fun serialize(value: State): String = JSONObject()
                .put(KEY_FONT_ID, value.activeFontId)
                .put(KEY_REEL_COUNTER, value.reelCounterEnabled)
                .toString()

            // `optBoolean` con default esplicito: un file scritto da una
            // versione precedente non ha la chiave, e deve leggersi come
            // "contatore acceso" invece che come `false` implicito — altrimenti
            // un aggiornamento dell'app spegnerebbe la feature di soppiatto.
            override fun deserialize(raw: String): State {
                val json = JSONObject(raw)
                return State(
                    activeFontId = json.optInt(KEY_FONT_ID, DEFAULT_FONT_ID),
                    reelCounterEnabled = json.optBoolean(
                        KEY_REEL_COUNTER,
                        DEFAULT_REEL_COUNTER_ENABLED,
                    ),
                )
            }
        },
        // File assente/corrotto ⇒ default. Non è enforcement: al massimo
        // l'overlay usa il font di sistema e il contatore resta acceso.
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
    /// Ritorna true se la scrittura è andata a buon fine. Legge-modifica-scrive
    /// così non azzera le altre preferenze del file.
    fun setActiveFontId(context: Context, fontId: Int): Boolean =
        store.mutate(context) { it.copy(activeFontId = fontId) }

    /// `true` se il conteggio dei reel è attivo. Letta dal servizio di
    /// accessibilità sia sull'hot path dello scroll sia nel calcolo del
    /// watched-set.
    fun isReelCounterEnabled(context: Context): Boolean =
        try {
            store.read(context).reelCounterEnabled
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read ui settings; reel counter default", e)
            DEFAULT_REEL_COUNTER_ENABLED
        }

    fun setReelCounterEnabled(context: Context, enabled: Boolean): Boolean =
        store.mutate(context) { it.copy(reelCounterEnabled = enabled) }

    // ---------------- test hooks ----------------

    internal fun invalidateCacheForTest() = store.invalidateCacheForTest()
}
