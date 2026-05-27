package com.dev.koru.service

import com.dev.koru.db.NativeAppRelation
import com.dev.koru.db.NativeInterval
import com.dev.koru.db.NativeProfile
import com.dev.koru.db.NativeWebsiteRule
import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Test PURI di [ProfileSnapshotLoader.build]: niente DB / Robolectric, le
 * operazioni di fetch sono stub. Verifico che l'ASSEMBLAGGIO dello snapshot sia
 * behavior-preserving rispetto all'inline che viveva in
 * [KoruAccessibilityService.loadProfiles]:
 *  - per ogni profilo (in ordine di lista) si chiamano app-relations + intervals
 *    keyed sul suo id;
 *  - le mappe risultanti combaciano con quanto ritornato dai fetch;
 *  - website-rules e wifi sono passati attraverso verbatim;
 *  - l'ORDINE delle invocazioni di fetch e' quello originale (profili →
 *    per-profilo apps+intervals → rules → wifi).
 */
class ProfileSnapshotLoaderTest {

    private fun profile(id: Int) = NativeProfile(
        id = id,
        title = "P$id",
        typeCombinations = 0,
        onConditions = 0,
        operator = 0,
        dayFlags = 0,
        blockNotifications = false,
        blockLaunch = false,
        isEnabled = true,
        isLocked = false,
        onUntil = 0L,
        lockedUntil = 0L,
        pausedUntil = 0L,
        blockingMode = 0,
        blockUnsupportedBrowsers = false,
        blockAdultContent = false,
        colorHex = "#5C8262",
        emoji = "E$id",
    )

    private fun relation(pkg: String, profileId: Int) =
        NativeAppRelation(pkg, profileId, true, null, null)

    private fun interval(id: Int, profileId: Int) =
        NativeInterval(id, profileId, 0, 60, true)

    @Test
    fun build_assemblesPerProfileMapsKeyedById() {
        val profiles = listOf(profile(1), profile(2))
        val rules = mapOf(1 to listOf(NativeWebsiteRule(10, 1, "reddit", 0, false, true)))
        val wifis = mapOf(2 to setOf("HomeWifi"))

        val snap = ProfileSnapshotLoader.build(
            fetchProfiles = { profiles },
            fetchAppRelations = { id -> listOf(relation("pkg$id", id)) },
            fetchIntervals = { id -> listOf(interval(id * 100, id)) },
            fetchWebsiteRules = { rules },
            fetchWifis = { wifis },
        )

        assertThat(snap.profiles).isEqualTo(profiles)
        // Mappe app/intervals keyed sull'id di OGNI profilo della lista.
        assertThat(snap.profileApps.keys).containsExactly(1, 2)
        assertThat(snap.profileApps[1]).containsExactly(relation("pkg1", 1))
        assertThat(snap.profileApps[2]).containsExactly(relation("pkg2", 2))
        assertThat(snap.profileIntervals[1]).containsExactly(interval(100, 1))
        assertThat(snap.profileIntervals[2]).containsExactly(interval(200, 2))
        // Rules + wifi passano attraverso verbatim.
        assertThat(snap.websiteRulesCache).isEqualTo(rules)
        assertThat(snap.profileWifis).isEqualTo(wifis)
    }

    @Test
    fun build_emptyProfiles_yieldsEmptyPerProfileMaps() {
        val snap = ProfileSnapshotLoader.build(
            fetchProfiles = { emptyList() },
            fetchAppRelations = { error("must not be called for empty profile list") },
            fetchIntervals = { error("must not be called for empty profile list") },
            fetchWebsiteRules = { emptyMap() },
            fetchWifis = { emptyMap() },
        )
        assertThat(snap.profiles).isEmpty()
        assertThat(snap.profileApps).isEmpty()
        assertThat(snap.profileIntervals).isEmpty()
        assertThat(snap.websiteRulesCache).isEmpty()
        assertThat(snap.profileWifis).isEmpty()
    }

    @Test
    fun build_fetchOrder_matchesOriginalInline() {
        // L'ordine deve essere: profiles → (per ogni profilo, in ordine:
        // appRelations(id) poi intervals(id)) → websiteRules → wifis. Una
        // divergenza qui significherebbe un cambio di comportamento osservabile
        // (es. cursori DB aperti in ordine diverso).
        val calls = mutableListOf<String>()
        ProfileSnapshotLoader.build(
            fetchProfiles = { calls.add("profiles"); listOf(profile(1), profile(2)) },
            fetchAppRelations = { id -> calls.add("apps($id)"); emptyList() },
            fetchIntervals = { id -> calls.add("intervals($id)"); emptyList() },
            fetchWebsiteRules = { calls.add("rules"); emptyMap() },
            fetchWifis = { calls.add("wifis"); emptyMap() },
        )
        assertThat(calls).containsExactly(
            "profiles",
            "apps(1)", "intervals(1)",
            "apps(2)", "intervals(2)",
            "rules",
            "wifis",
        ).inOrder()
    }

    @Test
    fun build_preservesProfileListOrder() {
        // L'ordine della lista profili (che guida il loop) e' preservato as-is.
        val profiles = listOf(profile(3), profile(1), profile(2))
        val snap = ProfileSnapshotLoader.build(
            fetchProfiles = { profiles },
            fetchAppRelations = { emptyList() },
            fetchIntervals = { emptyList() },
            fetchWebsiteRules = { emptyMap() },
            fetchWifis = { emptyMap() },
        )
        assertThat(snap.profiles.map { it.id }).containsExactly(3, 1, 2).inOrder()
    }
}
