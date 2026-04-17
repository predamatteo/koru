package com.dev.koru.content

import android.content.Context
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONObject

/**
 * Detector YouTube: riconosce Shorts da view-ids (nel reel_watch_fragment).
 */
class YouTubeDetector(context: Context) {
    companion object {
        const val PACKAGE = "com.google.android.youtube"
        private const val MAX_DEPTH = 12
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
        return if (walkContains(root, shortsIds)) DetectedSection.YouTubeShorts else null
    }

    private fun walkContains(
        node: AccessibilityNodeInfo,
        targetIds: Set<String>,
        depth: Int = 0,
    ): Boolean {
        if (depth > MAX_DEPTH) return false
        val rid = node.viewIdResourceName?.substringAfter(":id/")
        if (rid != null && rid in targetIds) return true
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (walkContains(child, targetIds, depth + 1)) return true
        }
        return false
    }
}
