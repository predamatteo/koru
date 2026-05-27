package com.dev.koru.channels.blocking

import android.app.Activity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Un singolo "concern" del canale `com.koru/blocking`. Ogni handler dichiara i
 * metodi di sua competenza e li serve quando il router glieli inoltra.
 *
 * ARCH-09: il vecchio [com.dev.koru.channels.BlockingMethodChannel] era un
 * god-facade con ~29 `when` cases che mescolavano 7+ concern (service lifecycle,
 * inventory app, usage-stats, quick-block, azioni app, device-info, limiti,
 * filtro notifiche, wifi). Per evitare ogni rischio di `MissingPluginException`
 * il NOME del canale e la registrazione in `MainActivity` restano INVARIATI: la
 * decomposizione è puramente interna. `BlockingMethodChannel` diventa un router
 * sottile che dispatcha ogni method name a uno di questi handler. Il contratto
 * di wire (method name, argomenti, shape del risultato) è byte-identico a prima.
 */
internal interface BlockingCallHandler {

    /// I method name che questo handler serve. Il router usa questo set per
    /// costruire la tabella di dispatch e per verificare che non ci siano
    /// collisioni tra handler (ogni metodo appartiene a esattamente un handler).
    val methods: Set<String>

    /**
     * Serve [call] producendo il risultato su [result]. Invocato dal router solo
     * se `call.method in methods`, quindi l'implementazione può assumere che il
     * metodo sia di sua competenza. [activity] è la stessa Activity passata a
     * `BlockingMethodChannel.register` (necessaria per Intent / system services).
     */
    fun handle(call: MethodCall, result: MethodChannel.Result, activity: Activity)
}

/**
 * Dart `int` piccoli (fino a ~2.1B) entrano nel MethodChannel come Integer;
 * valori più grandi (es. timestamps) come Long. `call.argument<Long>` fa un cast
 * runtime che CRASHA se il valore arriva come Integer. Questo helper gestisce
 * entrambi in modo safe. Spostato qui da `BlockingMethodChannel` (era un'estensione
 * file-private) perché condiviso da più handler (usage-stats, quick-block).
 */
internal fun MethodCall.longArg(name: String): Long = when (val v = argument<Any>(name)) {
    is Long -> v
    is Int -> v.toLong()
    is Number -> v.toLong()
    else -> 0L
}
