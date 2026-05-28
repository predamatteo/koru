package com.dev.koru.service

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Test puri (no Robolectric, no mock) per [isStaleOverlayClick], la funzione di
 * guardia chiamata dal callback onReturnHome dell'overlay per evitare di
 * eseguire GLOBAL_ACTION_BACK / HOME sull'app sbagliata quando l'overlay e'
 * rimasto stale sopra un foreground diverso dal target originale.
 *
 * Bug originale: limite Instagram raggiunto + overlay attivo + power off +
 * apertura WhatsApp da notification shade sul lock screen. L'overlay restava
 * stale sopra WhatsApp e il tap su "Don't open Instagram" chiudeva WhatsApp.
 */
class StaleOverlayClickTest {

    @Test
    fun `targetPackage vuoto non e mai stale`() {
        // Nessun target memorizzato → niente da confrontare → trust-the-system.
        assertFalse(isStaleOverlayClick("", "com.whatsapp", "com.whatsapp"))
        assertFalse(isStaleOverlayClick("", null, null))
    }

    @Test
    fun `realFg uguale al target non e stale (happy path)`() {
        // Utente in Instagram, overlay attivo, click su "Don't open Instagram".
        assertFalse(
            isStaleOverlayClick(
                targetPackage = "com.instagram.android",
                realForegroundPackage = "com.instagram.android",
                accessibilityForegroundPackage = "com.instagram.android",
            ),
        )
    }

    @Test
    fun `realFg diverso dal target e stale (bug case)`() {
        // Bug riportato dall'utente: target=Instagram, foreground=WhatsApp.
        // UsageStats e' authoritative quando disponibile.
        assertTrue(
            isStaleOverlayClick(
                targetPackage = "com.instagram.android",
                realForegroundPackage = "com.whatsapp",
                accessibilityForegroundPackage = "com.instagram.android",
            ),
        )
    }

    @Test
    fun `realFg null e accFg uguale al target non e stale`() {
        // UsageStats indisponibile (permesso revocato runtime, raro).
        // Cadiamo sull'evento Accessibility recente: target match → non-stale.
        assertFalse(
            isStaleOverlayClick(
                targetPackage = "com.instagram.android",
                realForegroundPackage = null,
                accessibilityForegroundPackage = "com.instagram.android",
            ),
        )
    }

    @Test
    fun `realFg null e accFg diverso dal target e stale`() {
        // UsageStats indisponibile ma l'evento Accessibility piu' recente
        // gia' segnala foreground diverso dal target → stale.
        assertTrue(
            isStaleOverlayClick(
                targetPackage = "com.instagram.android",
                realForegroundPackage = null,
                accessibilityForegroundPackage = "com.whatsapp",
            ),
        )
    }

    @Test
    fun `entrambi null e fail-safe non-stale (trust the system)`() {
        // Stato unknown ovunque. Una "falsa difesa" qui bloccherebbe il click
        // di un utente realmente sull'app limitata: meglio procedere col path
        // normale (mancata difesa < falsa difesa).
        assertFalse(
            isStaleOverlayClick(
                targetPackage = "com.instagram.android",
                realForegroundPackage = null,
                accessibilityForegroundPackage = null,
            ),
        )
    }
}
