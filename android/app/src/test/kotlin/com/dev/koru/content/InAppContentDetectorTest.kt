package com.dev.koru.content

import android.content.Context
import android.view.accessibility.AccessibilityNodeInfo
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import io.mockk.every
import io.mockk.mockk
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Tests for [InAppContentDetector] — the package → detector dispatcher.
 *
 * Robolectric is required because the underlying [InstagramDetector] and
 * [YouTubeDetector] read view-id JSON from real Android resources during
 * their `init` block.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class InAppContentDetectorTest {

    private lateinit var context: Context
    private lateinit var detector: InAppContentDetector

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        detector = InAppContentDetector(context)
    }

    private fun nodeWithId(resId: String): AccessibilityNodeInfo {
        val node = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { node.viewIdResourceName } returns resId
        every { node.childCount } returns 0
        return node
    }

    // -------- supports() --------

    @Test
    fun supports_instagramPackage_returnsTrue() {
        assertThat(detector.supports(InstagramDetector.PACKAGE)).isTrue()
    }

    @Test
    fun supports_youTubePackage_returnsTrue() {
        assertThat(detector.supports(YouTubeDetector.PACKAGE)).isTrue()
    }

    @Test
    fun supports_unknownPackage_returnsFalse() {
        assertThat(detector.supports("com.other")).isFalse()
    }

    @Test
    fun supports_emptyPackage_returnsFalse() {
        assertThat(detector.supports("")).isFalse()
    }

    // -------- detect() --------

    @Test
    fun detect_unknownPackage_returnsNull() {
        val node = nodeWithId("com.other:id/whatever")
        assertThat(detector.detect("com.other", node)).isNull()
    }

    @Test
    fun detect_nullRoot_returnsNull() {
        assertThat(detector.detect(InstagramDetector.PACKAGE, null)).isNull()
        assertThat(detector.detect(YouTubeDetector.PACKAGE, null)).isNull()
        assertThat(detector.detect("com.other", null)).isNull()
    }

    @Test
    fun detect_instagramReels_returnsInstagramReels() {
        val root = nodeWithId("com.instagram.android:id/clips_viewer_view_pager")
        assertThat(detector.detect(InstagramDetector.PACKAGE, root))
            .isEqualTo(DetectedSection.InstagramReels)
    }

    @Test
    fun detect_youTubeShorts_returnsYouTubeShorts() {
        val root = nodeWithId("com.google.android.youtube:id/reel_recycler")
        assertThat(detector.detect(YouTubeDetector.PACKAGE, root))
            .isEqualTo(DetectedSection.YouTubeShorts)
    }

    @Test
    fun detect_routesByPackage_notByNodeContent() {
        // A node carrying an Instagram-shaped id but with the YouTube package
        // → YouTubeDetector runs, doesn't recognise the id, returns null.
        val root = nodeWithId("com.instagram.android:id/clips_viewer_view_pager")
        assertThat(detector.detect(YouTubeDetector.PACKAGE, root)).isNull()
    }
}
