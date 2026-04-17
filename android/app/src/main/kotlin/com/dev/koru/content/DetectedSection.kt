package com.dev.koru.content

/// Sezioni in-app rilevabili dall'AccessibilityService.
/// Wire-id string MUST match Flutter's [BlockedSection.wireId] enum.
sealed class DetectedSection(val wireId: String, val packageName: String) {
    object InstagramReels : DetectedSection("INSTAGRAM_REELS", "com.instagram.android")
    object InstagramStories : DetectedSection("INSTAGRAM_STORIES", "com.instagram.android")
    object InstagramExplore : DetectedSection("INSTAGRAM_EXPLORE", "com.instagram.android")
    object YouTubeShorts : DetectedSection("YOUTUBE_SHORTS", "com.google.android.youtube")

    companion object {
        val all: List<DetectedSection> = listOf(
            InstagramReels,
            InstagramStories,
            InstagramExplore,
            YouTubeShorts,
        )

        fun fromWireId(id: String): DetectedSection? = all.firstOrNull { it.wireId == id }
    }
}
