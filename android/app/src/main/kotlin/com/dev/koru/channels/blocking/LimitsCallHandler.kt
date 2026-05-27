package com.dev.koru.channels.blocking

import android.app.Activity
import com.dev.koru.service.AppUsageLimitsStore
import com.dev.koru.service.BypassCountStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Concern: limiti giornalieri per-app + contatore bypass (la frizione
 * progressiva è legata ai limiti `strict=false`). Estratto da
 * `BlockingMethodChannel` (ARCH-09); comportamento e wire-contract invariati,
 * con l'unica eccezione INTENZIONALE di `setAppDailyLimits` (CR-09, sotto).
 */
internal object LimitsCallHandler : BlockingCallHandler {

    override val methods = setOf(
        "getAppDailyLimits",
        "setAppDailyLimits",
        "getBypassCountToday",
        "resetBypassCount",
    )

    override fun handle(call: MethodCall, result: MethodChannel.Result, activity: Activity) {
        when (call.method) {
            "getAppDailyLimits" -> {
                // Schema scambiato col Dart: {pkg: {minutes:Int, strict:Bool}}.
                // Lo store gestisce backward compat sul disco; qui esponiamo
                // sempre il formato esteso così il Dart non deve disambiguare.
                val entries = AppUsageLimitsStore.read(activity.applicationContext)
                val out = entries.mapValues { (_, v) ->
                    mapOf("minutes" to v.minutes, "strict" to v.strict)
                }
                result.success(out)
            }
            "setAppDailyLimits" -> {
                @Suppress("UNCHECKED_CAST")
                val raw = call.argument<Map<String, Any>>("limits") ?: emptyMap()
                val parsed = raw.mapNotNull { (pkg, v) ->
                    val entry = parseLimitEntry(v) ?: return@mapNotNull null
                    pkg to entry
                }.toMap()
                // CR-09: `save` ritorna ora un Boolean (scrittura atomica
                // andata a buon fine o meno). Prima questo case faceva
                // `result.success(true)` incondizionato, quindi il Dart non
                // poteva sapere che un salvataggio di limiti (stato di
                // enforcement) era fallito. Propaghiamo il vero risultato.
                val saved = AppUsageLimitsStore.save(activity.applicationContext, parsed)
                result.success(saved)
            }
            "getBypassCountToday" -> {
                val pkg = call.argument<String>("packageName")
                    ?: return result.error("MISSING_ARG", "packageName required", null)
                result.success(
                    BypassCountStore.todayCount(activity.applicationContext, pkg),
                )
            }
            "resetBypassCount" -> {
                val pkg = call.argument<String>("packageName")
                    ?: return result.error("MISSING_ARG", "packageName required", null)
                BypassCountStore.reset(activity.applicationContext, pkg)
                result.success(true)
            }
        }
    }

    /**
     * Tollera tre forme che il Dart può inviare per un entry di limite:
     *   1. `Number` (legacy): solo i minuti, strict=true di default;
     *   2. `Map<String, Any>` con keys `minutes` (Number) + `strict` (Bool);
     *   3. qualunque altro tipo → null (ignorato in upstream).
     */
    private fun parseLimitEntry(raw: Any?): AppUsageLimitsStore.LimitEntry? = when (raw) {
        is Number -> AppUsageLimitsStore.LimitEntry(
            minutes = raw.toInt(),
            strict = true,
        )
        is Map<*, *> -> {
            val minutes = (raw["minutes"] as? Number)?.toInt() ?: 0
            val strict = raw["strict"] as? Boolean ?: true
            if (minutes > 0) {
                AppUsageLimitsStore.LimitEntry(minutes = minutes, strict = strict)
            } else null
        }
        else -> null
    }
}
