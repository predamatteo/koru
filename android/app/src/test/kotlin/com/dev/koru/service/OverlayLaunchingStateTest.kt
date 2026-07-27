package com.dev.koru.service

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.dev.koru.overlay.BlockReason
import com.google.common.truth.Truth.assertThat
import java.io.File
import java.util.concurrent.atomic.AtomicReference
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Regression guard del bug "scelgo la durata e per ~1s mi riappare l'overlay,
 * poi si apre l'app".
 *
 * Al tap su una durata il vecchio codice rimetteva `showDurationPicker = false`
 * PRIMA di far partire il bypass: la composizione tornava alla schermata di
 * blocco (col CountdownButton ricreato, quindi countdown daccapo) e restava
 * visibile per tutta la finestra del dismiss differito di 250ms — deliberato,
 * serve a non perdere la interaction grace del Background Activity Launch di
 * Android 12+, quindi NON è quel ritardo ad andare rimosso.
 *
 * Il fix è uno stato terminale [OverlayManager.isLaunching] che tiene la
 * schermata di blocco fuori dalla composizione fino allo smontaggio della
 * finestra. Vive in OverlayManager e non in un `remember` proprio perché
 * `show()` con lo STESSO package non ricrea la ComposeView: il reset deve
 * avvenire sopra l'early-return di `show()`, non alla costruzione della view.
 *
 * Qui testiamo lo STATO, non i pixel: il modulo non ha
 * `androidx.compose.ui:ui-test-junit4`.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class OverlayLaunchingStateTest {

    private val pkg = "com.instagram.android"
    private lateinit var manager: OverlayManager

    @Before
    fun setUp() {
        clearStoreState()
        manager = OverlayManager(ApplicationProvider.getApplicationContext<Context>())
    }

    @After
    fun tearDown() {
        clearStoreState()
    }

    /// Stesso pattern di OverlayManagerBypassTest: il file E la cache statica di
    /// BypassStore (singleton che sopravvive nel JVM di test).
    private fun clearStoreState() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        File(ctx.filesDir, "koru_bypasses.json").delete()
        val field = BypassStore::class.java.getDeclaredField("cache")
        field.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        (field.get(BypassStore) as AtomicReference<Any?>).set(null)
    }

    @Test
    fun freshOverlay_isNotLaunching() {
        manager.show(pkg, "Instagram", "Focus", reason = BlockReason.APP_BLOCKED)
        assertThat(manager.isLaunching()).isFalse()
    }

    @Test
    fun durationChosen_entersLaunchingState() {
        manager.show(pkg, "Instagram", "Focus", reason = BlockReason.APP_BLOCKED)
        manager.handleBypassChosen(5L * 60_000L)
        // È questo flag a impedire il ri-render della schermata di blocco nei
        // ~250ms fra il tap e la removeView.
        assertThat(manager.isLaunching()).isTrue()
    }

    @Test
    fun subsequentShow_samePackage_resetsLaunching() {
        // Il path che un `remember` in Compose NON coprirebbe: show() con lo
        // stesso pkg mentre l'overlay è ancora montato riusa la ComposeView.
        // Senza il reset sopra l'early-return l'overlay resterebbe su
        // "Opening …" invece di ri-bloccare.
        manager.show(pkg, "Instagram", "Focus", reason = BlockReason.APP_BLOCKED)
        manager.handleBypassChosen(5L * 60_000L)
        manager.show(pkg, "Instagram", "Focus", reason = BlockReason.APP_BLOCKED)
        assertThat(manager.isLaunching()).isFalse()
    }

    @Test
    fun subsequentShow_otherPackage_resetsLaunching() {
        manager.show(pkg, "Instagram", "Focus", reason = BlockReason.APP_BLOCKED)
        manager.handleBypassChosen(5L * 60_000L)
        manager.show("com.google.android.youtube", "YouTube", "Focus", reason = BlockReason.APP_BLOCKED)
        assertThat(manager.isLaunching()).isFalse()
    }

    @Test
    fun durationChosen_stillGrantsReasonAwareBypass() {
        // L'estrazione di handleBypassChosen dalla lambda `onBypass` non deve
        // cambiare il grant: reason dell'overlay corrente + scope per-package.
        manager.show(pkg, "Instagram", "Daily limit", reason = BlockReason.USAGE_LIMIT)
        manager.handleBypassChosen(5L * 60_000L)
        assertThat(OverlayManager.isBypassed(pkg)).isTrue()
        assertThat(OverlayManager.bypassReason(pkg)).isEqualTo(BlockReason.USAGE_LIMIT)
        assertThat(OverlayManager.isLimitBypassActive(pkg)).isTrue()
    }

    @Test
    fun durationChosen_onWebsiteBlock_keepsDomainScope() {
        // Blocco sito: lo scope del bypass resta il dominio, non il browser.
        manager.show(
            "com.android.chrome",
            "reddit.com",
            "Focus",
            reason = BlockReason.WEBSITE_BLOCKED,
            blockedDomain = "reddit.com",
        )
        manager.handleBypassChosen(5L * 60_000L)
        assertThat(OverlayManager.isBypassed("com.android.chrome", "reddit.com")).isTrue()
        assertThat(OverlayManager.isBypassed("com.android.chrome")).isFalse()
    }

    @Test
    fun durationChosen_invokesOnBypassOpenCallback() {
        var seenPkg: String? = null
        var seenDuration = 0L
        var seenDomain: String? = "sentinel"
        manager.onBypassOpen = { p, d, dom ->
            seenPkg = p
            seenDuration = d
            seenDomain = dom
        }
        manager.show(pkg, "Instagram", "Focus", reason = BlockReason.APP_BLOCKED)
        manager.handleBypassChosen(15L * 60_000L)
        assertThat(seenPkg).isEqualTo(pkg)
        assertThat(seenDuration).isEqualTo(15L * 60_000L)
        assertThat(seenDomain).isNull()
    }
}
