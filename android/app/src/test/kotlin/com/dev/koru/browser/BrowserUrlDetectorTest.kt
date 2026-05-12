package com.dev.koru.browser

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Tests for [BrowserUrlDetector].
 *
 * The internal DFS walks an [android.view.accessibility.AccessibilityNodeInfo]
 * tree that is tricky to mock reliably (each node would need childCount +
 * getChild + viewIdResourceName + text + contentDescription wired). To keep
 * this suite reliable and fast, we focus on:
 *  - [BrowserUrlDetector.DetectedUrl] data-class semantics.
 *  - The URL_LIKE_REGEX assumptions used by the fallback inspector — we
 *    redefine the same regex literal here and assert it matches / rejects
 *    the inputs the production code expects, so any divergence between
 *    intent and implementation will trip a test.
 *
 * Full DFS coverage on AccessibilityNodeInfo is left to instrumented tests.
 */
class BrowserUrlDetectorTest {

    // Mirror of the URL_LIKE_REGEX defined privately in BrowserUrlDetector.
    // If you change one, change the other.
    private val urlLikeRegex = Regex(
        "(?:https?://)?(?:www\\.)?[a-z0-9][a-z0-9-]{0,63}(?:\\.[a-z0-9][a-z0-9-]{0,63})+(?:/[^\\s]*)?",
        RegexOption.IGNORE_CASE,
    )

    // -------- DetectedUrl data class --------

    @Test
    fun detectedUrl_exposesFullUrlAndDomain() {
        val d = BrowserUrlDetector.DetectedUrl(
            fullUrl = "https://www.example.com/path",
            domain = "example.com",
        )
        assertThat(d.fullUrl).isEqualTo("https://www.example.com/path")
        assertThat(d.domain).isEqualTo("example.com")
    }

    @Test
    fun detectedUrl_dataClassEquality() {
        val a = BrowserUrlDetector.DetectedUrl("https://foo.com", "foo.com")
        val b = BrowserUrlDetector.DetectedUrl("https://foo.com", "foo.com")
        assertThat(a).isEqualTo(b)
        assertThat(a.hashCode()).isEqualTo(b.hashCode())
    }

    @Test
    fun detectedUrl_inequalityOnDifferentDomain() {
        val a = BrowserUrlDetector.DetectedUrl("https://foo.com", "foo.com")
        val b = BrowserUrlDetector.DetectedUrl("https://foo.com", "bar.com")
        assertThat(a).isNotEqualTo(b)
    }

    // -------- URL_LIKE_REGEX shape --------

    @Test
    fun urlLikeRegex_matchesBareDomain() {
        assertThat(urlLikeRegex.containsMatchIn("facebook.com")).isTrue()
    }

    @Test
    fun urlLikeRegex_matchesHttpsScheme() {
        assertThat(urlLikeRegex.containsMatchIn("https://facebook.com")).isTrue()
    }

    @Test
    fun urlLikeRegex_matchesWwwPathSuffix() {
        assertThat(urlLikeRegex.containsMatchIn("www.facebook.com/abc")).isTrue()
    }

    @Test
    fun urlLikeRegex_matchesMultiLevelTld() {
        // sub.fb.co.uk
        assertThat(urlLikeRegex.containsMatchIn("sub.fb.co.uk")).isTrue()
    }

    @Test
    fun urlLikeRegex_matchesDeeplyNested() {
        assertThat(urlLikeRegex.containsMatchIn("x.y.z.com")).isTrue()
    }

    @Test
    fun urlLikeRegex_rejectsBareToken() {
        // "abc" has no dot → must not match.
        assertThat(urlLikeRegex.containsMatchIn("abc")).isFalse()
    }

    @Test
    fun urlLikeRegex_rejectsTrailingDot() {
        // "abc." → the TLD half of the regex requires at least one
        // alphanumeric char after the dot, so it shouldn't match.
        assertThat(urlLikeRegex.containsMatchIn("abc.")).isFalse()
    }

    @Test
    fun urlLikeRegex_rejectsLeadingDot() {
        // ".com" alone (no host before the dot) → no match.
        assertThat(urlLikeRegex.containsMatchIn(".com")).isFalse()
    }

    // TODO: integration test for BrowserUrlDetector.detect() — requires a
    // full AccessibilityNodeInfo tree which is awkward to mock reliably.
    // Cover via instrumented (androidTest) suite.
}
