package com.dev.koru.browser

import android.view.accessibility.AccessibilityNodeInfo
import com.google.common.truth.Truth.assertThat
import io.mockk.every
import io.mockk.mockk
import org.junit.Test

/**
 * Unit tests for [UrlExtractor].
 *
 * Verifies the primary/fallback extraction policy:
 *  - For "TEXT" extractionMethod: prefer node.text, fall back to
 *    contentDescription if blank/null.
 *  - For "CONTENT_DESC" extractionMethod: prefer node.contentDescription,
 *    fall back to text if blank/null.
 *  - Returns null when both sources are blank/null.
 */
class UrlExtractorTest {

    private fun textConfig() = BrowserConfig(
        packageName = "com.android.chrome",
        viewId = "url_bar",
        viewType = 0,
        detectionMethod = "VIEW_ID",
        extractionMethod = "TEXT",
        clearUrl = true,
    )

    private fun contentDescConfig() = BrowserConfig(
        packageName = "org.mozilla.firefox",
        viewId = "ADDRESSBAR_URL_BOX",
        viewType = 0,
        detectionMethod = "COMPOSE_TEST_TAG",
        extractionMethod = "CONTENT_DESC",
        clearUrl = true,
    )

    // -------- TEXT method --------

    @Test
    fun textMethod_returnsTextWhenPresent() {
        val node = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { node.text } returns "https://www.koru.app"
        every { node.contentDescription } returns null

        assertThat(UrlExtractor.extract(node, textConfig()))
            .isEqualTo("https://www.koru.app")
    }

    @Test
    fun textMethod_fallsBackToContentDescriptionWhenTextNull() {
        val node = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { node.text } returns null
        every { node.contentDescription } returns "https://fallback.example"

        assertThat(UrlExtractor.extract(node, textConfig()))
            .isEqualTo("https://fallback.example")
    }

    @Test
    fun textMethod_fallsBackToContentDescriptionWhenTextBlank() {
        val node = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { node.text } returns "   "
        every { node.contentDescription } returns "https://fallback.example"

        assertThat(UrlExtractor.extract(node, textConfig()))
            .isEqualTo("https://fallback.example")
    }

    @Test
    fun textMethod_returnsNullWhenBothBlank() {
        val node = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { node.text } returns ""
        every { node.contentDescription } returns "   "

        assertThat(UrlExtractor.extract(node, textConfig())).isNull()
    }

    @Test
    fun textMethod_returnsNullWhenBothNull() {
        val node = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { node.text } returns null
        every { node.contentDescription } returns null

        assertThat(UrlExtractor.extract(node, textConfig())).isNull()
    }

    // -------- CONTENT_DESC method --------

    @Test
    fun contentDescMethod_returnsContentDescriptionWhenPresent() {
        val node = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { node.contentDescription } returns "https://www.koru.app"
        every { node.text } returns null

        assertThat(UrlExtractor.extract(node, contentDescConfig()))
            .isEqualTo("https://www.koru.app")
    }

    @Test
    fun contentDescMethod_fallsBackToTextWhenContentDescNull() {
        val node = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { node.contentDescription } returns null
        every { node.text } returns "https://from-text.example"

        assertThat(UrlExtractor.extract(node, contentDescConfig()))
            .isEqualTo("https://from-text.example")
    }

    @Test
    fun contentDescMethod_fallsBackToTextWhenContentDescBlank() {
        val node = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { node.contentDescription } returns ""
        every { node.text } returns "https://from-text.example"

        assertThat(UrlExtractor.extract(node, contentDescConfig()))
            .isEqualTo("https://from-text.example")
    }

    @Test
    fun contentDescMethod_returnsNullWhenBothBlank() {
        val node = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { node.contentDescription } returns null
        every { node.text } returns "   "

        assertThat(UrlExtractor.extract(node, contentDescConfig())).isNull()
    }

    @Test
    fun textMethod_primaryWinsWhenBothPresent() {
        val node = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { node.text } returns "primary-text"
        every { node.contentDescription } returns "secondary-desc"

        assertThat(UrlExtractor.extract(node, textConfig())).isEqualTo("primary-text")
    }

    @Test
    fun contentDescMethod_primaryWinsWhenBothPresent() {
        val node = mockk<AccessibilityNodeInfo>(relaxed = true)
        every { node.contentDescription } returns "primary-desc"
        every { node.text } returns "secondary-text"

        assertThat(UrlExtractor.extract(node, contentDescConfig())).isEqualTo("primary-desc")
    }
}
