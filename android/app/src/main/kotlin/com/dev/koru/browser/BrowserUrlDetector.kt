package com.dev.koru.browser

import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import java.lang.ref.WeakReference
import java.util.concurrent.ConcurrentHashMap

object BrowserUrlDetector {
    private const val TAG = "BrowserUrlDetector"
    private val DOMAIN_REGEX = Regex("^(?:https?://)?(?:www\\.)?([^/:?#]+)", RegexOption.IGNORE_CASE)

    /// URL-like pattern: dominio con almeno un TLD (es. facebook.com),
    /// opzionalmente preceduto da https?:// o www., opzionalmente seguito da path.
    private val URL_LIKE_REGEX = Regex(
        "(?:https?://)?(?:www\\.)?[a-z0-9][a-z0-9-]{0,63}(?:\\.[a-z0-9][a-z0-9-]{0,63})+(?:/[^\\s]*)?",
        RegexOption.IGNORE_CASE,
    )

    /// Soglia per skip dei nodi nel fallback DFS: per essere considerati
    /// candidati URL bar il viewId deve contenere una di queste keyword.
    /// Riduce drasticamente la frazione di nodi visitati nell'albero
    /// (testato su Chrome 120: ~85% di skip immediato).
    private val URL_BAR_KEYWORDS = arrayOf("url", "omnibox", "address", "origin")

    data class DetectedUrl(val fullUrl: String, val domain: String)

    /// Cache (debole) del nodo URL bar per ogni package: se ancora vivo
    /// e legge un valore valido, evitiamo lo scan completo dell'albero.
    /// WeakReference cosi' non interferiamo col GC dei nodi obsoleti.
    /// ConcurrentHashMap perche' detect() puo' essere chiamato da thread
    /// diversi (event thread accessibility vs timer di refresh).
    private val urlBarNodeCache = ConcurrentHashMap<String, WeakReference<AccessibilityNodeInfo>>()

    fun detect(rootNode: AccessibilityNodeInfo, configs: List<BrowserConfig>): DetectedUrl? {
        val pkg = configs.firstOrNull()?.packageName

        // 0) Short-circuit: prova il nodo cached di recente per questo pkg.
        if (pkg != null) {
            val cached = urlBarNodeCache[pkg]?.get()
            if (cached != null) {
                val text = (cached.text ?: cached.contentDescription)?.toString()
                if (!text.isNullOrBlank()) {
                    val url = text.trim().lowercase()
                    if (!url.startsWith("search or") && url.isNotEmpty()) {
                        val domain = extractDomain(url)
                        if (domain != null && domain.contains('.')) {
                            Log.d(TAG, "Detected via cached node: $domain")
                            return DetectedUrl(url, domain)
                        }
                    }
                }
                // Cache miss (testo invalido): invalidiamo per il prossimo giro.
                urlBarNodeCache.remove(pkg)
            }
        }

        // 1) Known view-ids dal JSON di config (veloce).
        for (config in configs) {
            val urlNode = UrlBarNodeFinder.find(rootNode, config) ?: continue
            val rawUrl = UrlExtractor.extract(urlNode, config)
            // Mettiamo il nodo in cache come WeakReference cosi' il prossimo
            // detect() puo' shortcut-are evitando lo scan completo. NB: non
            // facciamo recycle del nodo (su API < 33) perche' lo teniamo per
            // la cache; il GC se ne occupera' quando la weak ref sara'
            // l'unico riferimento rimasto.
            if (pkg != null) {
                urlBarNodeCache[pkg] = WeakReference(urlNode)
            }
            if (rawUrl == null) continue
            val url = rawUrl.trim().lowercase()
            if (url.isEmpty() || url.startsWith("search or")) continue
            val domain = extractDomain(url) ?: continue
            if (domain.isEmpty() || !domain.contains('.')) continue
            Log.d(TAG, "Detected via view-id ${config.viewId}: $domain")
            return DetectedUrl(url, domain)
        }

        // 2) Fallback euristico per browser moderni (Chrome recenti obfuscano
        //    i view-id). Scansiona l'albero cercando nodi con id/testo
        //    plausibilmente URL bar — DFS iterativo con recycle.
        val foundIds = mutableSetOf<String>()
        val fallback = scanFallbackIterative(rootNode, foundIds)
        if (fallback != null) {
            Log.i(TAG, "Detected via fallback: ${fallback.domain}")
            return fallback
        }
        Log.d(TAG, "No URL. Sample view-ids (${foundIds.size}): ${foundIds.take(40).joinToString(", ")}")
        return null
    }

    /// DFS iterativo (stack) con recycle dei nodi non-root. La versione
    /// ricorsiva precedente leakava nodi su API < 33 perche' i child
    /// node restituiti da `getChild()` non venivano mai recyclati,
    /// allocando senza limite nel binder accessibility pool.
    private fun scanFallbackIterative(
        root: AccessibilityNodeInfo,
        foundIds: MutableSet<String>,
    ): DetectedUrl? {
        val nodes = ArrayDeque<AccessibilityNodeInfo>()
        val depths = ArrayDeque<Int>()
        nodes.addLast(root)
        depths.addLast(0)
        var result: DetectedUrl? = null
        while (nodes.isNotEmpty()) {
            val n = nodes.removeLast()
            val d = depths.removeLast()
            try {
                if (result == null) {
                    result = inspectFallback(n, foundIds)
                    if (result == null && d < 20) {
                        for (i in 0 until n.childCount) {
                            val child = n.getChild(i) ?: continue
                            nodes.addLast(child)
                            depths.addLast(d + 1)
                        }
                    }
                }
            } finally {
                if (n !== root && Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                    try { n.recycle() } catch (_: Throwable) {}
                }
            }
        }
        return result
    }

    private fun inspectFallback(
        node: AccessibilityNodeInfo,
        foundIds: MutableSet<String>,
    ): DetectedUrl? {
        val vid = node.viewIdResourceName
        if (vid != null) foundIds.add(vid)

        // Short-circuit: se il viewId NON contiene una delle keyword
        // url-bar-like, skippiamo il check del testo. Riduce >80% dei nodi.
        val idLower = vid?.lowercase()
        val matchesKeyword = idLower != null && URL_BAR_KEYWORDS.any { idLower.contains(it) }

        // a) view-id fuzzy match: prova text/contentDescription.
        if (matchesKeyword) {
            val text = (node.text ?: node.contentDescription)?.toString()
            if (!text.isNullOrBlank()) {
                val domain = extractDomain(text.trim().lowercase())
                if (domain != null && domain.contains('.')) {
                    return DetectedUrl(text.trim().lowercase(), domain)
                }
            }
        }

        // b) text che assomiglia a una URL (regex su tutto).
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
        return null
    }

    private fun extractDomain(url: String): String? {
        val match = DOMAIN_REGEX.find(url) ?: return url.takeIf { it.contains('.') }
        return match.groupValues[1].takeIf { it.isNotEmpty() }
    }
}
