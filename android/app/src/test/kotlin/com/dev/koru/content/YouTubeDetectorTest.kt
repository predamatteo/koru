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
 * Tests for [YouTubeDetector] under Robolectric — loads the real
 * `res/raw/youtube_view_ids.json` so the shortsIds set is populated.
 *
 * Test design mirrors [InstagramDetectorTest]: small mocked node trees
 * carry the resource ids the detector scans for.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class YouTubeDetectorTest {

    private lateinit var context: Context
    private lateinit var detector: YouTubeDetector

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        detector = YouTubeDetector(context)
    }

    private fun nodeWithId(resId: String?): AccessibilityNodeInfo {
        val node = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { node.viewIdResourceName } returns resId
        every { node.childCount } returns 0
        return node
    }

    @Test
    fun packageConstantIsYouTube() {
        assertThat(YouTubeDetector.PACKAGE).isEqualTo("com.google.android.youtube")
    }

    @Test
    fun detect_nullRoot_returnsNull() {
        assertThat(detector.detect(null)).isNull()
    }

    @Test
    fun detect_shortsId_returnsYouTubeShorts() {
        // "reel_watch_fragment_container" is a known SHORTS id in the JSON.
        val root = nodeWithId("com.google.android.youtube:id/reel_watch_fragment_container")
        assertThat(detector.detect(root)).isEqualTo(DetectedSection.YouTubeShorts)
    }

    @Test
    fun detect_unknownId_returnsNull() {
        val root = nodeWithId("com.google.android.youtube:id/some_other_view")
        assertThat(detector.detect(root)).isNull()
    }

    @Test
    fun detect_nullViewId_returnsNull() {
        assertThat(detector.detect(nodeWithId(null))).isNull()
    }

    @Test
    fun detect_shortsIdInDeepChild_isFound() {
        // root has one child, the child carries the Shorts id.
        val child = nodeWithId("com.google.android.youtube:id/reel_recycler")
        val root = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { root.viewIdResourceName } returns null
        every { root.childCount } returns 1
        every { root.getChild(0) } returns child

        assertThat(detector.detect(root)).isEqualTo(DetectedSection.YouTubeShorts)
    }

    @Test
    fun detect_idWithoutPackagePrefix_stillMatches() {
        // substringAfter(":id/") falls through to the original string, so
        // a bare id matches as long as it's present in the loaded set.
        val root = nodeWithId("reel_player_page_container")
        assertThat(detector.detect(root)).isEqualTo(DetectedSection.YouTubeShorts)
    }
}
