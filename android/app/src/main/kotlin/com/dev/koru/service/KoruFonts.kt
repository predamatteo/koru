package com.dev.koru.service

import android.content.Context
import android.graphics.Typeface
import android.util.Log
import androidx.compose.ui.text.font.FontFamily
import java.util.concurrent.ConcurrentHashMap

/**
 * Risolve il font scelto dall'utente (in-app) in una [FontFamily] Compose per
 * l'overlay di blocco nativo.
 *
 * L'overlay gira nel processo `:accessibility`, che NON ha accesso a Hive (dove
 * vive la preferenza). Il font id arriva via [UiSettingsStore] (scritto dal main
 * process al cambio preferenza). Qui lo mappiamo al `.ttf` impacchettato negli
 * asset Flutter e ne costruiamo una FontFamily.
 *
 * Mirror della tabella di `lib/core/theme/font_catalog.dart` (`KoruFont.id` →
 * famiglia): id 0 = System (nessun asset → default Compose), 1-4 = font custom.
 * I file `.ttf` dichiarati nel `pubspec.yaml` (sezione `fonts:`) finiscono
 * nell'APK sotto `assets/flutter_assets/<asset path del pubspec>`.
 */
object KoruFonts {
    private const val TAG = "KoruFonts"

    /// id (KoruFont.id) → path dell'asset dentro l'AssetManager Android.
    /// Solo i font con un `.ttf` reale: id 0 (System) è assente di proposito
    /// (→ [resolve] ritorna null → font di sistema).
    private val assetByFontId: Map<Int, String> = mapOf(
        1 to "flutter_assets/assets/fonts/Goldman-Regular.ttf",
        2 to "flutter_assets/assets/fonts/Orbitron-Regular.ttf",
        3 to "flutter_assets/assets/fonts/ArchitectsDaughter-Regular.ttf",
        4 to "flutter_assets/assets/fonts/OpenDyslexic-Regular.ttf",
    )

    /// Cache fontId → FontFamily: leggere e parsare un `.ttf` dagli asset ad ogni
    /// `show()` dell'overlay (un window-event qualsiasi) sarebbe I/O sprecato —
    /// coerente con le lezioni del perf audit (niente lavoro pesante per evento).
    private val cache = ConcurrentHashMap<Int, FontFamily>()

    /// Path dell'asset per [fontId], o null per System (0) / id sconosciuto.
    /// Puro (niente I/O): è l'unità testabile della mappatura.
    fun assetPath(fontId: Int): String? = assetByFontId[fontId]

    /// [FontFamily] per il font scelto, o **null** per il system font (id 0) o se
    /// il caricamento fallisce. Fail-safe: un path errato/asset mancante non
    /// crasha l'overlay, degrada al font di sistema.
    fun resolve(context: Context, fontId: Int): FontFamily? {
        val path = assetByFontId[fontId] ?: return null // System / sconosciuto
        cache[fontId]?.let { return it }
        return try {
            val family = FontFamily(Typeface.createFromAsset(context.assets, path))
            cache[fontId] = family
            family
        } catch (e: Exception) {
            Log.w(TAG, "Font asset load failed for id=$fontId ($path); using system font", e)
            null
        }
    }
}
