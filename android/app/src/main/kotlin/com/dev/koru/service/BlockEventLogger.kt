package com.dev.koru.service

import android.content.Context
import android.util.Log
import com.dev.koru.channels.ServiceEventChannel
import com.dev.koru.db.NativeDatabase
import com.dev.koru.db.NativeProfile
import org.json.JSONObject

/**
 * Bookkeeping degli eventi di blocco: scrittura su DB
 * ([NativeDatabase.insertBlockSession] / [NativeDatabase.insertRestrictedAccessEvent])
 * + emissione sull'event-channel verso Flutter ([ServiceEventChannel]).
 *
 * ## Perche' esiste (ARCH-05)
 * Questi side-effect di logging/analytics erano sparsi in ~10 punti dentro il
 * dispatcher di [KoruAccessibilityService], ciascuno con il proprio
 * `try { ... } catch (_: Exception) {}` ripetuto e la propria costruzione di
 * JSONObject. Li centralizzo qui per snellire il dispatcher (che resta
 * responsabile SOLO di decisione + overlay + HOME). Comportamento invariato:
 *  - stesso ordine delle insert, stessi eventType/restrictionType;
 *  - lo stesso try/catch silenzioso (il logging non deve mai far fallire
 *    l'enforcement) — vedi nota sotto;
 *  - stessa forma del JSON emesso sul channel.
 *
 * La costruzione del JSON ([blockingStateJson] / [sectionJson]) e' PURA e
 * `internal` → unit-testabile senza Android (vedi `BlockEventLoggerTest`).
 *
 * NB sui catch silenziosi: sono preservati VERBATIM dall'inline precedente
 * (CR-09 riguarda gli store *state-bearing*; questi sono log/analytics, dove
 * inghiottire l'eccezione e' il comportamento storico voluto e fuori dallo
 * scope di questo refactor behavior-preserving).
 */
object BlockEventLogger {

    private const val TAG = "BlockEventLogger"

    // --- DB bookkeeping ------------------------------------------------------

    /**
     * Logga un solo `restricted_access_event` (nessuna block-session).
     * Replica i call site "solo restricted-access" del dispatcher.
     */
    fun logRestrictedAccess(
        context: Context,
        packageName: String,
        eventType: Int,
        restrictionType: Int,
        timestamp: Long,
    ) {
        try {
            NativeDatabase.insertRestrictedAccessEvent(
                context,
                packageName,
                eventType = eventType,
                restrictionType = restrictionType,
                timestamp = timestamp,
            )
        } catch (_: Exception) {}
    }

    /**
     * Logga una block-session + un `restricted_access_event` di tipo TRIGGERED
     * (eventType=0), nello STESSO try/catch dell'inline originale: se la prima
     * insert lancia, la seconda viene saltata (comportamento preservato).
     *
     * @param sessionName il `name` della block-session: il package per
     *   app/focus, `"$package/$wireId"` per le sezioni, il dominio per i siti
     *   (deciso dal chiamante, come prima).
     */
    fun logBlockSessionAndAccess(
        context: Context,
        sessionName: String,
        packageName: String,
        restrictionType: Int,
        timestamp: Long,
    ) {
        try {
            NativeDatabase.insertBlockSession(context, sessionName, timestamp)
            NativeDatabase.insertRestrictedAccessEvent(
                context,
                packageName,
                eventType = 0, // TRIGGERED
                restrictionType = restrictionType,
                timestamp = timestamp,
            )
        } catch (_: Exception) {}
    }

    // --- Event channel emission ----------------------------------------------

    /** JSON del messaggio BLOCKING_STATE. Puro → testabile. */
    internal fun blockingStateJson(
        isBlocking: Boolean,
        packageName: String,
        profile: NativeProfile?,
    ): String = JSONObject().apply {
        put("type", "BLOCKING_STATE")
        put("isBlocking", isBlocking)
        put("packageName", packageName)
        put("profileId", profile?.id ?: -1)
        put("profileTitle", profile?.title ?: "")
    }.toString()

    /** JSON del messaggio IN_APP_SECTION_DETECTED. Puro → testabile. */
    internal fun sectionJson(
        packageName: String,
        sectionWireId: String,
        profile: NativeProfile,
    ): String = JSONObject().apply {
        put("type", "IN_APP_SECTION_DETECTED")
        put("packageName", packageName)
        put("section", sectionWireId)
        put("profileId", profile.id)
        put("profileTitle", profile.title)
    }.toString()

    fun emitBlockingState(isBlocking: Boolean, packageName: String, profile: NativeProfile?) {
        ServiceEventChannel.sendEvent(blockingStateJson(isBlocking, packageName, profile))
    }

    fun emitSection(packageName: String, sectionWireId: String, profile: NativeProfile) {
        ServiceEventChannel.sendEvent(sectionJson(packageName, sectionWireId, profile))
    }
}
