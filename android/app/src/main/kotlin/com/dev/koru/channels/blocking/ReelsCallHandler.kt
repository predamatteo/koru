package com.dev.koru.channels.blocking

import android.app.Activity
import com.dev.koru.service.ReelCountStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Concern: contatore dei reel/short scrollati ([ReelCountStore]).
 *
 * SOLA lettura: chi conta è il motore di enforcement, qui non si incrementa e
 * non si configura nulla. Il contatore non ha più un interruttore — è sempre
 * attivo, quindi Instagram e YouTube sono sempre nel watched-set.
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
        }
    }
}
