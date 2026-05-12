package com.dev.koru.browser

import com.dev.koru.db.NativeWebsiteRule
import com.google.common.truth.Truth.assertThat
import io.mockk.every
import io.mockk.mockk
import org.junit.Test

/**
 * Unit tests for [WebsiteMatcher].
 *
 * Coverage:
 *  - Domain match (blockingType == 0) exact + subdomain.
 *  - FIX A15 anti-spoofing: no false positives on lookalike domains and
 *    query strings.
 *  - Keyword match (blockingType == 1) with isAnywhereInUrl true/false.
 *  - Edge cases: empty rule, unknown blockingType, case insensitivity,
 *    rule trimming, port handling, fallback domain extraction from URL.
 *  - [WebsiteMatcher.matchesAny] aggregation.
 */
class WebsiteMatcherTest {

    private fun rule(name: String, type: Int, anywhere: Boolean = false): NativeWebsiteRule =
        mockk<NativeWebsiteRule>(relaxed = true).apply {
            every { this@apply.name } returns name
            every { blockingType } returns type
            every { isAnywhereInUrl } returns anywhere
        }

    // -------- Domain match (blockingType == 0) --------

    @Test
    fun domainMatch_exact_returnsTrue() {
        val r = rule("facebook.com", type = 0)
        assertThat(WebsiteMatcher.matches(r, "facebook.com", "facebook.com")).isTrue()
    }

    @Test
    fun domainMatch_subdomain_returnsTrue() {
        val r = rule("facebook.com", type = 0)
        assertThat(WebsiteMatcher.matches(r, "m.facebook.com", "m.facebook.com")).isTrue()
    }

    @Test
    fun domainMatch_nonMatchingDomain_returnsFalse() {
        val r = rule("facebook.com", type = 0)
        assertThat(WebsiteMatcher.matches(r, "nofacebook.com", "nofacebook.com")).isFalse()
    }

    @Test
    fun domainMatch_spoofedSuffix_returnsFalse() {
        // FIX A15: "facebook.com.evil.com" must NOT match rule "facebook.com".
        val r = rule("facebook.com", type = 0)
        assertThat(
            WebsiteMatcher.matches(r, "facebook.com.evil.com", "facebook.com.evil.com")
        ).isFalse()
    }

    @Test
    fun domainMatch_ruleInQueryString_returnsFalse() {
        // FIX A15: the rule name appearing in the URL query string must NOT
        // cause a domain-match false positive.
        val r = rule("news.com", type = 0)
        val url = "https://example.com/?q=news.com"
        val domain = "example.com"
        assertThat(WebsiteMatcher.matches(r, url, domain)).isFalse()
    }

    @Test
    fun emptyRuleName_returnsFalse() {
        val r = rule("", type = 0)
        assertThat(WebsiteMatcher.matches(r, "facebook.com", "facebook.com")).isFalse()
    }

    @Test
    fun blankRuleName_returnsFalse() {
        val r = rule("   ", type = 0)
        assertThat(WebsiteMatcher.matches(r, "facebook.com", "facebook.com")).isFalse()
    }

    @Test
    fun domainMatch_isCaseInsensitive() {
        val r = rule("FACEBOOK.COM", type = 0)
        assertThat(WebsiteMatcher.matches(r, "facebook.com", "facebook.com")).isTrue()
    }

    @Test
    fun ruleNameIsTrimmed() {
        val r = rule("  facebook.com  ", type = 0)
        assertThat(WebsiteMatcher.matches(r, "facebook.com", "facebook.com")).isTrue()
    }

    @Test
    fun domainMatch_extractsDomainFromUrlWhenDomainBlank() {
        val r = rule("facebook.com", type = 0)
        // Pass empty domain so extractDomain() fallback kicks in.
        assertThat(
            WebsiteMatcher.matches(r, "https://m.facebook.com/path", "")
        ).isTrue()
    }

    @Test
    fun domainMatch_urlWithPort_matches() {
        val r = rule("facebook.com", type = 0)
        // Domain blank → extractDomain strips the port.
        assertThat(WebsiteMatcher.matches(r, "facebook.com:8080", "")).isTrue()
    }

    // -------- Keyword match (blockingType == 1) --------

    @Test
    fun keywordMatch_anywhereInUrl_pathContainsKeyword_returnsTrue() {
        val r = rule("shorts", type = 1, anywhere = true)
        val url = "https://youtube.com/shorts/abc"
        val domain = "youtube.com"
        assertThat(WebsiteMatcher.matches(r, url, domain)).isTrue()
    }

    @Test
    fun keywordMatch_inDomainOnly_returnsTrue() {
        val r = rule("shorts", type = 1, anywhere = false)
        assertThat(
            WebsiteMatcher.matches(r, "shorts.example.com", "shorts.example.com")
        ).isTrue()
    }

    @Test
    fun keywordMatch_inDomainOnly_pathOnly_returnsFalse() {
        // With anywhere=false, only the domain is searched: a keyword found
        // only in the path must NOT cause a match.
        val r = rule("shorts", type = 1, anywhere = false)
        val url = "https://example.com/shorts/"
        val domain = "example.com"
        assertThat(WebsiteMatcher.matches(r, url, domain)).isFalse()
    }

    // -------- Unknown blockingType --------

    @Test
    fun unknownBlockingType_returnsFalse() {
        val r = rule("facebook.com", type = 99)
        assertThat(WebsiteMatcher.matches(r, "facebook.com", "facebook.com")).isFalse()
    }

    // -------- matchesAny --------

    @Test
    fun matchesAny_emptyList_returnsFalse() {
        assertThat(
            WebsiteMatcher.matchesAny(emptyList(), "facebook.com", "facebook.com")
        ).isFalse()
    }

    @Test
    fun matchesAny_oneOfManyMatches_returnsTrue() {
        val rules = listOf(
            rule("twitter.com", type = 0),
            rule("facebook.com", type = 0),
            rule("instagram.com", type = 0),
        )
        assertThat(
            WebsiteMatcher.matchesAny(rules, "facebook.com", "facebook.com")
        ).isTrue()
    }

    @Test
    fun matchesAny_noMatch_returnsFalse() {
        val rules = listOf(
            rule("twitter.com", type = 0),
            rule("instagram.com", type = 0),
        )
        assertThat(
            WebsiteMatcher.matchesAny(rules, "facebook.com", "facebook.com")
        ).isFalse()
    }
}
