package com.dev.koru.content

import android.content.Context
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONObject

/**
 * Detector Instagram: riconosce Reels / Stories / Explore da view-ids.
 *
 * I view-id sono caricati da `res/raw/instagram_view_ids.json` per permettere
 * hot-update dopo update di Instagram senza rebuild nativo. DFS limitato a
 * depth 12 per evitare stalli su UI grandi.
 */
class InstagramDetector(context: Context) {
    companion object {
        const val PACKAGE = "com.instagram.android"
        private const val MAX_DEPTH = 12
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

        walk(root) { node ->
            val rid = node.viewIdResourceName ?: return@walk
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

    private fun walk(
        node: AccessibilityNodeInfo,
        depth: Int = 0,
        visit: (AccessibilityNodeInfo) -> Unit,
    ) {
        if (depth > MAX_DEPTH) return
        visit(node)
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            walk(child, depth + 1, visit)
        }
    }
}

private fun org.json.JSONArray.toStringSet(): Set<String> {
    val result = mutableSetOf<String>()
    for (i in 0 until length()) result.add(getString(i))
    return result
}
