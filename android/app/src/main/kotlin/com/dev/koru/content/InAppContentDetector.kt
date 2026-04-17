package com.dev.koru.content

import android.content.Context
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Dispatcher che routa l'AccessibilityNodeInfo al detector giusto in base al
 * package dell'app in foreground.
 *
 * Mantenuto come singleton (lazy init dei detector, che leggono i JSON una
 * volta sola) e throttled externally dalla caller (KoruAccessibilityService).
 */
class InAppContentDetector(context: Context) {
    private val instagram = InstagramDetector(context)
    private val youtube = YouTubeDetector(context)

    fun detect(packageName: String, root: AccessibilityNodeInfo?): DetectedSection? {
        if (root == null) return null
        return when (packageName) {
            InstagramDetector.PACKAGE -> instagram.detect(root)
            YouTubeDetector.PACKAGE -> youtube.detect(root)
            else -> null
        }
    }

    fun supports(packageName: String): Boolean =
        packageName == InstagramDetector.PACKAGE || packageName == YouTubeDetector.PACKAGE
}
