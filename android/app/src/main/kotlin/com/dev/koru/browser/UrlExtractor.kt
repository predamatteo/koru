package com.dev.koru.browser

import android.view.accessibility.AccessibilityNodeInfo

object UrlExtractor {
    fun extract(node: AccessibilityNodeInfo, config: BrowserConfig): String? =
        when (config.extractionMethod) {
            "CONTENT_DESC" -> node.contentDescription?.toString()
            else -> node.text?.toString()
        }
}
