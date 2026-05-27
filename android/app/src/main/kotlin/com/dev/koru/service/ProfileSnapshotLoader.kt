package com.dev.koru.service

import android.content.Context
import com.dev.koru.db.NativeAppRelation
import com.dev.koru.db.NativeDatabase
import com.dev.koru.db.NativeInterval
import com.dev.koru.db.NativeProfile
import com.dev.koru.db.NativeWebsiteRule

/**
 * Carica lo stato dei profili dal DB nativo e lo assembla in uno
 * [ProfilesSnapshot] immutabile.
 *
 * ## Perche' esiste (ARCH-05)
 * La costruzione dello snapshot viveva inline in
 * [KoruAccessibilityService.loadProfiles], in mezzo ai side-effect del service
 * (try/catch, `AtomicReference.set`, timing log, `applyDynamicPackageFilter`).
 * La estraggo qui per renderla testabile: l'ASSEMBLAGGIO (loop per-profilo +
 * costruzione delle mappe) e' logica pura una volta iniettate le operazioni di
 * fetch, mentre il service resta il solo responsabile della pubblicazione
 * atomica dello snapshot e del filtro dinamico dei package.
 *
 * Behavior-preserving: l'ORDINE delle query e la struttura delle mappe sono
 * IDENTICI all'inline precedente:
 *   getEnabledProfiles
 *   → per ogni profilo (in ordine di lista): getAppRelationsForProfile(id),
 *     poi getIntervalsForProfile(id)
 *   → getAllWebsiteRulesForEnabledProfiles
 *   → getWifiSsidsByProfile
 *
 * [build] e' `internal` e prende le operazioni di fetch come lambda → unit-test
 * puro senza DB/Robolectric (vedi `ProfileSnapshotLoaderTest`). [load] e' il
 * wrapper di produzione che chiude sulle statiche di [NativeDatabase] nello
 * stesso ordine; gli eventuali errori SQLite si propagano al chiamante, che
 * mantiene il fallback a [ProfilesSnapshot.EMPTY] (come prima).
 */
object ProfileSnapshotLoader {

    /**
     * Assembla lo snapshot dalle operazioni di fetch iniettate. PURO: nessuna
     * dipendenza Android, nessun side-effect oltre alle lambda passate. L'ordine
     * di invocazione e la forma delle mappe (`toMap()` per fissare lo snapshot)
     * replicano l'inline originale.
     */
    internal fun build(
        fetchProfiles: () -> List<NativeProfile>,
        fetchAppRelations: (profileId: Int) -> List<NativeAppRelation>,
        fetchIntervals: (profileId: Int) -> List<NativeInterval>,
        fetchWebsiteRules: () -> Map<Int, List<NativeWebsiteRule>>,
        fetchWifis: () -> Map<Int, Set<String>>,
    ): ProfilesSnapshot {
        val newProfiles = fetchProfiles()
        val newProfileApps = mutableMapOf<Int, List<NativeAppRelation>>()
        val intervalsByProfile = mutableMapOf<Int, List<NativeInterval>>()
        for (p in newProfiles) {
            newProfileApps[p.id] = fetchAppRelations(p.id)
            intervalsByProfile[p.id] = fetchIntervals(p.id)
        }
        val newRules = fetchWebsiteRules()
        val newWifis = fetchWifis()

        return ProfilesSnapshot(
            profiles = newProfiles,
            profileApps = newProfileApps.toMap(),
            websiteRulesCache = newRules,
            profileIntervals = intervalsByProfile.toMap(),
            profileWifis = newWifis,
        )
    }

    /**
     * Variante di produzione: carica lo snapshot da [NativeDatabase] per il
     * [context] dato. Wrappa [build] con le statiche reali; nessun try/catch qui
     * (lo gestisce il chiamante, come nell'inline originale).
     */
    fun load(context: Context): ProfilesSnapshot = build(
        fetchProfiles = { NativeDatabase.getEnabledProfiles(context) },
        fetchAppRelations = { id -> NativeDatabase.getAppRelationsForProfile(context, id) },
        fetchIntervals = { id -> NativeDatabase.getIntervalsForProfile(context, id) },
        fetchWebsiteRules = { NativeDatabase.getAllWebsiteRulesForEnabledProfiles(context) },
        fetchWifis = { NativeDatabase.getWifiSsidsByProfile(context) },
    )
}
