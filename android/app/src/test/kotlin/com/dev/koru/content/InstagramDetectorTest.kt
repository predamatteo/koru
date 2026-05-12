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
 * Tests for [InstagramDetector] using Robolectric (real `res/raw` resources
 * provide the view-id JSON, so the detector reads its real id sets).
 *
 * [AccessibilityNodeInfo] is mocked with MockK — we build small trees that
 * carry the resource ids the detector looks for.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class InstagramDetectorTest {

    private lateinit var context: Context
    private lateinit var detector: InstagramDetector

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        detector = InstagramDetector(context)
    }

    private fun nodeWithId(resId: String): AccessibilityNodeInfo {
        val node = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { node.viewIdResourceName } returns resId
        every { node.childCount } returns 0
        return node
    }

    @Test
    fun packageConstantIsInstagram() {
        assertThat(InstagramDetector.PACKAGE).isEqualTo("com.instagram.android")
    }

    @Test
    fun detect_nullRoot_returnsNull() {
        assertThat(detector.detect(null)).isNull()
    }

    @Test
    fun detect_reelsId_returnsInstagramReels() {
        // "clips_viewer_view_pager" is a known REELS id in the bundled JSON.
        val root = nodeWithId("com.instagram.android:id/clips_viewer_view_pager")
        assertThat(detector.detect(root)).isEqualTo(DetectedSection.InstagramReels)
    }

    @Test
    fun detect_storiesId_returnsInstagramStories() {
        val root = nodeWithId("com.instagram.android:id/story_viewer_fragment")
        assertThat(detector.detect(root)).isEqualTo(DetectedSection.InstagramStories)
    }

    @Test
    fun detect_exploreId_returnsInstagramExplore() {
        val root = nodeWithId("com.instagram.android:id/explore_grid_recycler_view")
        assertThat(detector.detect(root)).isEqualTo(DetectedSection.InstagramExplore)
    }

    @Test
    fun detect_unknownId_returnsNull() {
        val root = nodeWithId("com.instagram.android:id/some_random_thing")
        assertThat(detector.detect(root)).isNull()
    }

    @Test
    fun detect_nullViewId_returnsNull() {
        val node = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { node.viewIdResourceName } returns null
        every { node.childCount } returns 0
        assertThat(detector.detect(node)).isNull()
    }

    @Test
    fun detect_storiesAndReelsBothPresent_storiesHasPriority() {
        // Build a root (reels id) with a single child carrying a stories id.
        // The detector accumulates both flags, then picks stories.
        val storiesChild = nodeWithId("com.instagram.android:id/story_viewer_fragment")
        val root = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { root.viewIdResourceName } returns
            "com.instagram.android:id/clips_viewer_view_pager"
        every { root.childCount } returns 1
        every { root.getChild(0) } returns storiesChild

        assertThat(detector.detect(root)).isEqualTo(DetectedSection.InstagramStories)
    }

    @Test
    fun detect_idWithoutPackagePrefix_stillMatches() {
        // substringAfter(":id/") returns the raw string if ":id/" is absent.
        // The bundled JSON entries themselves are bare names like
        // "clips_viewer_view_pager", so a viewIdResourceName equal to the
        // bare name must still match.
        val root = nodeWithId("clips_viewer_view_pager")
        assertThat(detector.detect(root)).isEqualTo(DetectedSection.InstagramReels)
    }
}
