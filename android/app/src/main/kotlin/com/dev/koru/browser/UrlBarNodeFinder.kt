package com.dev.koru.browser

import android.view.accessibility.AccessibilityNodeInfo

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
        if (results.isNotEmpty()) return results[0]
        if (viewId.contains(":id/")) {
            val r2 = node.findAccessibilityNodeInfosByViewId(viewId)
            if (r2.isNotEmpty()) return r2[0]
        }
        return null
    }

    private fun findByComposeTestTag(node: AccessibilityNodeInfo, testTag: String): AccessibilityNodeInfo? {
        val tag = node.extras?.getString("androidx.compose.ui.semantics.testTag")
        if (tag == testTag) return node
        val vid = node.viewIdResourceName
        if (vid != null && vid.endsWith(testTag)) return node
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val r = findByComposeTestTag(child, testTag)
            if (r != null) return r
        }
        return null
    }
}
