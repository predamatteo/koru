package com.dev.koru.content

import android.content.Context
import android.os.Build
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONObject

/**
 * Detector YouTube: riconosce Shorts da view-ids (nel reel_watch_fragment).
 *
 * DFS iterativo con stack + recycle dei nodi non-root su API < 33. Vedi
 * [InstagramDetector] per il razionale completo della migrazione da
 * ricorsiva → iterativa. MAX_DEPTH a 20 (era 12) per dare margine ai feed
 * Shorts moderni con multiple RecyclerView annidate. Early-exit appena
 * trovato il primo Shorts id: niente bisogno di visitare l'intero albero.
 */
class YouTubeDetector(context: Context) {
    companion object {
        const val PACKAGE = "com.google.android.youtube"
        private const val MAX_DEPTH = 20
    }

    private val shortsIds: Set<String>

    init {
        val resId = context.resources.getIdentifier("youtube_view_ids", "raw", context.packageName)
        shortsIds = if (resId == 0) {
            emptySet()
        } else {
            val json = JSONObject(
                context.resources.openRawResource(resId).bufferedReader().readText()
            )
            val array = json.optJSONArray("SHORTS")
            val set = mutableSetOf<String>()
            if (array != null) {
                for (i in 0 until array.length()) set.add(array.getString(i))
            }
            set
        }
    }

    fun detect(root: AccessibilityNodeInfo?): DetectedSection? {
        if (root == null || shortsIds.isEmpty()) return null
        return if (walkContainsIterative(root, shortsIds)) DetectedSection.YouTubeShorts else null
    }

    private fun walkContainsIterative(
        root: AccessibilityNodeInfo,
        targetIds: Set<String>,
    ): Boolean {
        val nodes = ArrayDeque<AccessibilityNodeInfo>()
        val depths = ArrayDeque<Int>()
        nodes.addLast(root)
        depths.addLast(0)
        var found = false
        while (nodes.isNotEmpty()) {
            val n = nodes.removeLast()
            val d = depths.removeLast()
            try {
                if (!found) {
                    val rid = n.viewIdResourceName?.substringAfter(":id/")
                    if (rid != null && rid in targetIds) {
                        found = true
                    }
                }
                // Se gia' trovato, smettiamo di esplorare ma continuiamo
                // a drenare lo stack per recyclare i nodi rimanenti.
                if (!found && d < MAX_DEPTH) {
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
        return found
    }
}
