package com.dev.koru.channels.blocking

import android.app.Activity
import android.content.Intent
import com.dev.koru.service.KoruAccessibilityService
import com.dev.koru.service.ReelCountStore
import com.dev.koru.service.UiSettingsStore
import com.dev.koru.widget.KoruUsageWidgetProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Concern: contatore dei reel/short scrollati ([ReelCountStore]) e suo
 * interruttore ([UiSettingsStore]).
 *
 * Solo lettura del dato: chi conta è il motore di enforcement, qui non si
 * incrementa nulla. L'unica scrittura è l'interruttore, ed è quella che
 * richiede il broadcast di reload — vedi [setEnabled].
 */
internal object ReelsCallHandler : BlockingCallHandler {

    /// Tetto ai giorni restituiti in una sola chiamata. Coincide con quanto lo
    /// store conserva: chiedere di piu' darebbe una coda di zeri indistinguibile
    /// da "quei giorni non hai scrollato", che e' un modo silenzioso di mentire.
    private const val MAX_HISTORY_DAYS = 30
    private const val DEFAULT_HISTORY_DAYS = 7

    override val methods = setOf(
        "getReelCountsToday",
        "getReelCountsHistory",
        "isReelCounterEnabled",
        "setReelCounterEnabled",
    )

    override fun handle(call: MethodCall, result: MethodChannel.Result, activity: Activity) {
        val ctx = activity.applicationContext
        when (call.method) {
            // Schema: {wireId: count}, con i wireId di DetectedSection
            // (INSTAGRAM_REELS / YOUTUBE_SHORTS). Mappa e non lista di coppie
            // cosi' il Dart puo' leggere una sorgente per chiave senza scorrere.
            "getReelCountsToday" -> result.success(ReelCountStore.todayCounts(ctx))

            // Schema: [{dayStart: Long, counts: {wireId: Int}}], dal giorno piu'
            // recente al piu' vecchio, con i giorni vuoti gia' inclusi a zero.
            "getReelCountsHistory" -> {
                val days = (call.argument<Number>("days")?.toInt() ?: DEFAULT_HISTORY_DAYS)
                    .coerceIn(1, MAX_HISTORY_DAYS)
                result.success(
                    ReelCountStore.recentDays(ctx, days).map { day ->
                        mapOf("dayStart" to day.dayStartMs, "counts" to day.counts)
                    },
                )
            }

            "isReelCounterEnabled" -> result.success(UiSettingsStore.isReelCounterEnabled(ctx))

            "setReelCounterEnabled" -> setEnabled(call, result, activity)
        }
    }

    /**
     * L'interruttore non e' solo cosmetico: decide se Instagram e YouTube
     * restano nel watched-set dell'AccessibilityService (vedi
     * `WatchedPackageCalculator.observationPackages`). Senza il broadcast di
     * reload, accendere la feature non avrebbe effetto fino al prossimo
     * ricalcolo spontaneo — cioe' l'utente vedrebbe zero e penserebbe che non
     * funziona — e spegnerla continuerebbe a far consegnare eventi che nessuno
     * usa piu'.
     *
     * Propaga il vero esito della scrittura (CR-09) invece di un `true` fisso:
     * un interruttore che dice "fatto" senza aver salvato tornerebbe indietro
     * al riavvio senza spiegazioni.
     */
    private fun setEnabled(call: MethodCall, result: MethodChannel.Result, activity: Activity) {
        val enabled = call.argument<Boolean>("enabled")
            ?: return result.error("MISSING_ARG", "enabled required", null)
        val ctx = activity.applicationContext
        val saved = UiSettingsStore.setReelCounterEnabled(ctx, enabled)
        if (saved) {
            ctx.sendBroadcast(
                Intent(KoruAccessibilityService.ACTION_RELOAD_PROFILES)
                    .setPackage(ctx.packageName),
            )
            // La pill sul widget deve sparire (o ricomparire) subito: e' un
            // cambio di configurazione, non un tick, quindi salta il throttle.
            KoruUsageWidgetProvider.requestUpdate(ctx, "reel-counter-toggled", force = true)
        }
        result.success(saved)
    }
}
