package com.dev.koru.content

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Tests for the [DetectedSection] sealed class.
 *
 * IMPORTANT — Flutter <-> Kotlin alignment: the four `wireId` strings asserted
 * below MUST exactly match the values of the Dart `BlockedSection` enum
 * declared in `lib/domain/entities/blocked_section.dart`. If you rename one
 * side without renaming the other, blocked-section events from native will
 * silently fail to map on the Flutter side. Cross-language assertion is
 * out of scope here — keep this comment as a reminder for reviewers.
 */
class DetectedSectionTest {

    @Test
    fun instagramReels_hasExpectedWireIdAndPackage() {
        assertThat(DetectedSection.InstagramReels.wireId).isEqualTo("INSTAGRAM_REELS")
        assertThat(DetectedSection.InstagramReels.packageName)
            .isEqualTo("com.instagram.android")
    }

    @Test
    fun instagramStories_hasExpectedWireIdAndPackage() {
        assertThat(DetectedSection.InstagramStories.wireId).isEqualTo("INSTAGRAM_STORIES")
        assertThat(DetectedSection.InstagramStories.packageName)
            .isEqualTo("com.instagram.android")
    }

    @Test
    fun instagramExplore_hasExpectedWireIdAndPackage() {
        assertThat(DetectedSection.InstagramExplore.wireId).isEqualTo("INSTAGRAM_EXPLORE")
        assertThat(DetectedSection.InstagramExplore.packageName)
            .isEqualTo("com.instagram.android")
    }

    @Test
    fun youTubeShorts_hasExpectedWireIdAndPackage() {
        assertThat(DetectedSection.YouTubeShorts.wireId).isEqualTo("YOUTUBE_SHORTS")
        assertThat(DetectedSection.YouTubeShorts.packageName)
            .isEqualTo("com.google.android.youtube")
    }

    @Test
    fun all_containsExactlyFourSections() {
        assertThat(DetectedSection.all).hasSize(4)
        assertThat(DetectedSection.all).containsExactly(
            DetectedSection.InstagramReels,
            DetectedSection.InstagramStories,
            DetectedSection.InstagramExplore,
            DetectedSection.YouTubeShorts,
        )
    }

    @Test
    fun fromWireId_returnsCorrectSection_forKnownIds() {
        assertThat(DetectedSection.fromWireId("INSTAGRAM_REELS"))
            .isEqualTo(DetectedSection.InstagramReels)
        assertThat(DetectedSection.fromWireId("INSTAGRAM_STORIES"))
            .isEqualTo(DetectedSection.InstagramStories)
        assertThat(DetectedSection.fromWireId("INSTAGRAM_EXPLORE"))
            .isEqualTo(DetectedSection.InstagramExplore)
        assertThat(DetectedSection.fromWireId("YOUTUBE_SHORTS"))
            .isEqualTo(DetectedSection.YouTubeShorts)
    }

    @Test
    fun fromWireId_unknownReturnsNull() {
        assertThat(DetectedSection.fromWireId("BOGUS")).isNull()
    }

    @Test
    fun fromWireId_emptyReturnsNull() {
        assertThat(DetectedSection.fromWireId("")).isNull()
    }

    @Test
    fun allWireIdsAreUnique() {
        val ids = DetectedSection.all.map { it.wireId }
        assertThat(ids).containsNoDuplicates()
    }
}
