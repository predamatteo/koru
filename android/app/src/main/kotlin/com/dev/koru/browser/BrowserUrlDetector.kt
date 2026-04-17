package com.dev.koru.browser

import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo

object BrowserUrlDetector {
    private const val TAG = "BrowserUrlDetector"
    private val DOMAIN_REGEX = Regex("^(?:https?://)?(?:www\\.)?([^/:?#]+)", RegexOption.IGNORE_CASE)

    data class DetectedUrl(val fullUrl: String, val domain: String)

    fun detect(rootNode: AccessibilityNodeInfo, configs: List<BrowserConfig>): DetectedUrl? {
        for (config in configs) {
            val urlNode = UrlBarNodeFinder.find(rootNode, config) ?: continue
            val rawUrl = UrlExtractor.extract(urlNode, config) ?: continue
            val url = rawUrl.trim().lowercase()
            if (url.isEmpty() || url.startsWith("search or")) continue
            val domain = extractDomain(url) ?: continue
            if (domain.isEmpty() || !domain.contains('.')) continue
            Log.d(TAG, "Detected: $domain")
            return DetectedUrl(url, domain)
        }
        return null
    }

    private fun extractDomain(url: String): String? {
        val match = DOMAIN_REGEX.find(url) ?: return url.takeIf { it.contains('.') }
        return match.groupValues[1].takeIf { it.isNotEmpty() }
    }
}
