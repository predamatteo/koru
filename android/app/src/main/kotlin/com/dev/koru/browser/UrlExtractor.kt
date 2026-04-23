package com.dev.koru.browser

import android.view.accessibility.AccessibilityNodeInfo

object UrlExtractor {
    /// Estrae la URL dal nodo della URL bar. Prova il metodo dichiarato in
    /// config; se ritorna null/vuoto cade sull'altro — alcuni browser (es.
    /// Chrome quando la URL bar è minimizzata durante lo scroll) espongono
    /// l'URL solo via contentDescription anche se il view-id è dichiarato
    /// come "TEXT".
    fun extract(node: AccessibilityNodeInfo, config: BrowserConfig): String? {
        val primary = when (config.extractionMethod) {
            "CONTENT_DESC" -> node.contentDescription?.toString()
            else -> node.text?.toString()
        }
        if (!primary.isNullOrBlank()) return primary

        val fallback = when (config.extractionMethod) {
            "CONTENT_DESC" -> node.text?.toString()
            else -> node.contentDescription?.toString()
        }
        return if (!fallback.isNullOrBlank()) fallback else null
    }
}
