package com.dev.koru.content

import android.content.Context
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Dispatcher che routa l'AccessibilityNodeInfo al detector giusto in base al
 * package dell'app in foreground.
 *
 * Mantenuto come singleton (lazy init dei detector, che leggono i JSON una
 * volta sola) e throttled externally dalla caller (KoruAccessibilityService).
 *
 * NB: il root node passato a [detect] e' di proprieta' del caller; il
 * recycle (su API < 33) e' responsabilita' del caller. I detector
 * internamente recyclano solo i child node che allocano via getChild().
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

    /**
     * La sezione "feed verticale infinito" a cui appartiene la view che ha
     * emesso uno scroll, oppure `null` se quello scroll non viene da un pager
     * di reel/short.
     *
     * A differenza di [detect] questa NON cammina l'albero: riceve il solo
     * `viewIdResourceName` del `source` dell'evento. È la differenza fra un
     * costo accettabile sull'hot path dello scroll e una DFS per ogni evento.
     *
     * @param shortViewId la parte dopo `:id/` (il chiamante la estrae una volta
     *   sola dal nodo sorgente).
     */
    fun reelPagerSection(packageName: String, shortViewId: String?): DetectedSection? {
        if (shortViewId.isNullOrEmpty()) return null
        return when (packageName) {
            InstagramDetector.PACKAGE ->
                if (instagram.isReelsPager(shortViewId)) DetectedSection.InstagramReels else null
            YouTubeDetector.PACKAGE ->
                if (youtube.isShortsPager(shortViewId)) DetectedSection.YouTubeShorts else null
            else -> null
        }
    }
}
