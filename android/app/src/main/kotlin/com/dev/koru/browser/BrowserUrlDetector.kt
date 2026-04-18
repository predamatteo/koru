package com.dev.koru.browser

import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo

object BrowserUrlDetector {
    private const val TAG = "BrowserUrlDetector"
    private val DOMAIN_REGEX = Regex("^(?:https?://)?(?:www\\.)?([^/:?#]+)", RegexOption.IGNORE_CASE)

    /// URL-like pattern: dominio con almeno un TLD (es. facebook.com),
    /// opzionalmente preceduto da https?:// o www., opzionalmente seguito da path.
    private val URL_LIKE_REGEX = Regex(
        "(?:https?://)?(?:www\\.)?[a-z0-9][a-z0-9-]{0,63}(?:\\.[a-z0-9][a-z0-9-]{0,63})+(?:/[^\\s]*)?",
        RegexOption.IGNORE_CASE,
    )

    data class DetectedUrl(val fullUrl: String, val domain: String)

    fun detect(rootNode: AccessibilityNodeInfo, configs: List<BrowserConfig>): DetectedUrl? {
        // 1) Known view-ids dal JSON di config (veloce).
        for (config in configs) {
            val urlNode = UrlBarNodeFinder.find(rootNode, config) ?: continue
            val rawUrl = UrlExtractor.extract(urlNode, config) ?: continue
            val url = rawUrl.trim().lowercase()
            if (url.isEmpty() || url.startsWith("search or")) continue
            val domain = extractDomain(url) ?: continue
            if (domain.isEmpty() || !domain.contains('.')) continue
            Log.d(TAG, "Detected via view-id ${config.viewId}: $domain")
            return DetectedUrl(url, domain)
        }

        // 2) Fallback euristico per browser moderni (Chrome recenti obfuscano
        //    i view-id). Scansiona l'albero cercando nodi con id/testo
        //    plausibilmente URL bar.
        val foundIds = mutableSetOf<String>()
        val fallback = scanFallback(rootNode, foundIds, depth = 0)
        if (fallback != null) {
            Log.i(TAG, "Detected via fallback: ${fallback.domain}")
            return fallback
        }
        Log.d(TAG, "No URL. Sample view-ids (${foundIds.size}): ${foundIds.take(40).joinToString(", ")}")
        return null
    }

    private fun scanFallback(
        node: AccessibilityNodeInfo,
        foundIds: MutableSet<String>,
        depth: Int,
    ): DetectedUrl? {
        if (depth > 20) return null
        val vid = node.viewIdResourceName
        if (vid != null) foundIds.add(vid)

        // a) view-id fuzzy match (url / address / origin).
        val idLower = vid?.lowercase()
        if (idLower != null &&
            (idLower.contains("url") ||
                idLower.contains("address") ||
                idLower.endsWith(":id/origin"))
        ) {
            val text = (node.text ?: node.contentDescription)?.toString()
            if (!text.isNullOrBlank()) {
                val domain = extractDomain(text.trim().lowercase())
                if (domain != null && domain.contains('.')) {
                    return DetectedUrl(text.trim().lowercase(), domain)
                }
            }
        }

        // b) text che assomiglia a una URL (include domain con TLD).
        val rawText = node.text?.toString()
        if (rawText != null && rawText.length < 500 && !rawText.contains(' ')) {
            val match = URL_LIKE_REGEX.find(rawText.lowercase())
            if (match != null) {
                val candidate = match.value
                val domain = extractDomain(candidate)
                if (domain != null && domain.contains('.')) {
                    return DetectedUrl(candidate, domain)
                }
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val r = scanFallback(child, foundIds, depth + 1)
            if (r != null) return r
        }
        return null
    }

    private fun extractDomain(url: String): String? {
        val match = DOMAIN_REGEX.find(url) ?: return url.takeIf { it.contains('.') }
        return match.groupValues[1].takeIf { it.isNotEmpty() }
    }
}
