package com.dev.koru.browser

import android.os.Build
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Strategy: trova il nodo della URL bar dato un [BrowserConfig].
 *
 * - VIEW_ID  → `findAccessibilityNodeInfosByViewId` (path veloce, ufficiale).
 * - COMPOSE_TEST_TAG → fallback per app Compose dove il viewId non e' un
 *   resource id ma una test tag pubblicata nei semantics extras.
 *
 * Recycle policy: `findAccessibilityNodeInfosByViewId` puo' ritornare piu'
 * di un nodo (es. nello stesso albero ci sono tab inattive con la stessa
 * id). Manteniamo `results[0]` (la prima visibile in document order, di
 * solito quella attiva) e recyclamo immediatamente gli altri. Il caller
 * e' responsabile del recycle del nodo restituito.
 */
object UrlBarNodeFinder {
    fun find(rootNode: AccessibilityNodeInfo, config: BrowserConfig): AccessibilityNodeInfo? {
        return when (config.detectionMethod) {
            "COMPOSE_TEST_TAG" -> findByComposeTestTag(rootNode, config.viewId)
            else -> findByViewId(rootNode, config.viewId)
        }
    }

    private fun findByViewId(node: AccessibilityNodeInfo, viewId: String): AccessibilityNodeInfo? {
        val results = node.findAccessibilityNodeInfosByViewId(
            if (viewId.startsWith(":id/")) viewId else ":id/$viewId"
        )
        val first = pickFirstRecycleRest(results)
        if (first != null) return first
        if (viewId.contains(":id/")) {
            val r2 = node.findAccessibilityNodeInfosByViewId(viewId)
            return pickFirstRecycleRest(r2)
        }
        return null
    }

    /// Prende il primo nodo della lista e recycle (su API < 33) tutti gli
    /// altri. Ritorna null se la lista e' vuota.
    private fun pickFirstRecycleRest(results: List<AccessibilityNodeInfo>?): AccessibilityNodeInfo? {
        if (results.isNullOrEmpty()) return null
        val first = results[0]
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            for (i in 1 until results.size) {
                try { results[i].recycle() } catch (_: Throwable) {}
            }
        }
        return first
    }

    /// DFS iterativo per Compose test tag: visita l'albero, controlla
    /// semantics extras + viewId fallback. Recycle dei nodi visitati che
    /// non sono quello target. Per evitare di recyclare il nodo "winner"
    /// prima di restituirlo, lo togliamo dallo stack early-exit.
    private fun findByComposeTestTag(
        root: AccessibilityNodeInfo,
        testTag: String,
    ): AccessibilityNodeInfo? {
        // Check root direttamente (path veloce, evita di mettere root nello stack).
        if (matchesTestTag(root, testTag)) return root

        val stack = ArrayDeque<AccessibilityNodeInfo>()
        for (i in 0 until root.childCount) {
            root.getChild(i)?.let { stack.addLast(it) }
        }
        var winner: AccessibilityNodeInfo? = null
        while (stack.isNotEmpty()) {
            val n = stack.removeLast()
            if (winner == null && matchesTestTag(n, testTag)) {
                winner = n
                continue // non recyclare il winner
            }
            try {
                if (winner == null) {
                    for (i in 0 until n.childCount) {
                        n.getChild(i)?.let { stack.addLast(it) }
                    }
                }
            } finally {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                    try { n.recycle() } catch (_: Throwable) {}
                }
            }
        }
        return winner
    }

    private fun matchesTestTag(node: AccessibilityNodeInfo, testTag: String): Boolean {
        val tag = node.extras?.getString("androidx.compose.ui.semantics.testTag")
        if (tag == testTag) return true
        val vid = node.viewIdResourceName
        return vid != null && vid.endsWith(testTag)
    }
}
