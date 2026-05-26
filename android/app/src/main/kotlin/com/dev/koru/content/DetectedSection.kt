package com.dev.koru.content

/// Sezioni in-app rilevabili dall'AccessibilityService.
/// Wire-id string MUST match Flutter's [BlockedSection.wireId] enum.
sealed class DetectedSection(val wireId: String, val packageName: String) {
    object InstagramReels : DetectedSection("INSTAGRAM_REELS", "com.instagram.android")
    object InstagramStories : DetectedSection("INSTAGRAM_STORIES", "com.instagram.android")
    object InstagramExplore : DetectedSection("INSTAGRAM_EXPLORE", "com.instagram.android")
    object YouTubeShorts : DetectedSection("YOUTUBE_SHORTS", "com.google.android.youtube")

    companion object {
        // `by lazy` è OBBLIGATORIO: con un inizializzatore eager
        // (`val all = listOf(InstagramReels, …)`) scatta il bug di ordine di
        // inizializzazione delle sealed class Kotlin (KT-8970). Quando `.all` è
        // il PRIMO accesso al tipo, gli `object` annidati non sono ancora
        // inizializzati e vengono catturati come `null` nella lista (il primo,
        // InstagramReels, risultava null → NPE in fromWireId / usi di `.all`).
        // `by lazy` rinvia la costruzione al primo get, quando l'init della
        // classe esterna è già completato e gli object sono risolvibili.
        val all: List<DetectedSection> by lazy {
            listOf(
                InstagramReels,
                InstagramStories,
                InstagramExplore,
                YouTubeShorts,
            )
        }

        fun fromWireId(id: String): DetectedSection? = all.firstOrNull { it.wireId == id }
    }
}
