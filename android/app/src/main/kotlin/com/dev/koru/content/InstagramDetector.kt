package com.dev.koru.content

import android.content.Context
import android.os.Build
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONObject

/**
 * Detector Instagram: riconosce Reels / Stories / Explore da view-ids.
 *
 * I view-id sono caricati da `res/raw/instagram_view_ids.json` per permettere
 * hot-update dopo update di Instagram senza rebuild nativo.
 *
 * Implementazione DFS iterativa con stack: la versione ricorsiva precedente
 * andava in stack overflow su alberi UI molto profondi (Reels feed con
 * RecyclerView nested) e, più sottilmente, leakava AccessibilityNodeInfo
 * perche' i child nodes non venivano recyclati. Su API < 33 questo causava
 * il temuto "TooManyAccessibilityNodeInfosInUse" del binder, con il sintomo
 * di drop completo degli AccessibilityEvent dopo qualche minuto di uso
 * intensivo. Su API 33+ recycle e' deprecated (no-op safe), ma chiamarlo
 * non costa nulla. MAX_DEPTH alzato a 20 per dare margine sui feed moderni.
 */
class InstagramDetector(context: Context) {
    companion object {
        const val PACKAGE = "com.instagram.android"
        private const val MAX_DEPTH = 20
    }

    private val reelsIds: Set<String>
    private val storiesIds: Set<String>
    private val exploreIds: Set<String>

    init {
        val resId = context.resources.getIdentifier("instagram_view_ids", "raw", context.packageName)
        if (resId == 0) {
            reelsIds = emptySet()
            storiesIds = emptySet()
            exploreIds = emptySet()
        } else {
            val json = JSONObject(
                context.resources.openRawResource(resId).bufferedReader().readText()
            )
            reelsIds = json.optJSONArray("REELS")?.toStringSet() ?: emptySet()
            storiesIds = json.optJSONArray("STORIES")?.toStringSet() ?: emptySet()
            exploreIds = json.optJSONArray("EXPLORE")?.toStringSet() ?: emptySet()
        }
    }

    fun detect(root: AccessibilityNodeInfo?): DetectedSection? {
        if (root == null) return null

        var reels = false
        var stories = false
        var explore = false

        walkIterative(root) { node ->
            val rid = node.viewIdResourceName ?: return@walkIterative
            val short = rid.substringAfter(":id/")
            if (short in reelsIds) reels = true
            if (short in storiesIds) stories = true
            if (short in exploreIds) explore = true
        }

        // Stories has priority over Reels when both match (stories reuse reel_viewer_* ids).
        return when {
            stories -> DetectedSection.InstagramStories
            reels -> DetectedSection.InstagramReels
            explore -> DetectedSection.InstagramExplore
            else -> null
        }
    }

    /// DFS iterativo con stack esplicito. Per ogni nodo non-root, dopo aver
    /// pushato i figli, recycle il nodo (su API < 33). Il root non viene
    /// mai recyclato qui: e' di proprieta' del caller.
    /// Track la depth tramite un secondo stack parallelo (potremmo
    /// incapsulare in un Pair ma evitare allocazioni nel hot path matters).
    private inline fun walkIterative(
        root: AccessibilityNodeInfo,
        visit: (AccessibilityNodeInfo) -> Unit,
    ) {
        val nodes = ArrayDeque<AccessibilityNodeInfo>()
        val depths = ArrayDeque<Int>()
        nodes.addLast(root)
        depths.addLast(0)
        while (nodes.isNotEmpty()) {
            val n = nodes.removeLast()
            val d = depths.removeLast()
            try {
                visit(n)
                if (d < MAX_DEPTH) {
                    for (i in 0 until n.childCount) {
                        val child = n.getChild(i) ?: continue
                        nodes.addLast(child)
                        depths.addLast(d + 1)
                    }
                }
            } finally {
                if (n !== root && Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                    try { n.recycle() } catch (_: Throwable) {}
                }
            }
        }
    }
}

private fun org.json.JSONArray.toStringSet(): Set<String> {
    val result = mutableSetOf<String>()
    for (i in 0 until length()) result.add(getString(i))
    return result
}
