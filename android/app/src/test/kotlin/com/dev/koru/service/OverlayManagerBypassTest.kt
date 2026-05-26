package com.dev.koru.service

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.dev.koru.overlay.BlockReason
import com.google.common.truth.Truth.assertThat
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Tests per lo stato di bypass *reason-aware* in [OverlayManager].
 *
 * Regression guard del bug "+5 min all'infinito sul cap giornaliero passando
 * dal blocco di profilo": un bypass concesso per un blocco di profilo
 * (APP_BLOCKED) NON deve contare come bypass del limite, mentre un bypass nato
 * dal limite (USAGE_LIMIT / BYPASS_EXPIRED) sì. È [isLimitBypassActive] a
 * decidere se il daily limit resta esigibile, in entrambi i path di
 * enforcement (KoruAccessibilityService e LockRunnable).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class OverlayManagerBypassTest {

    private val pkg = "com.instagram.android"

    @Before
    fun setUp() {
        // Aggancia il context (in produzione lo fa il costruttore di
        // OverlayManager) così i metodi companion raggiungono BypassStore,
        // poi parti da uno stato pulito.
        OverlayManager.attachContext(ApplicationProvider.getApplicationContext<Context>())
        OverlayManager.revokeAllBypasses()
    }

    @After
    fun tearDown() {
        OverlayManager.revokeAllBypasses()
    }

    @Test
    fun profileBypass_isNotLimitBypass() {
        OverlayManager.markBypassed(pkg, 5 * 60_000L, reason = BlockReason.APP_BLOCKED)
        assertThat(OverlayManager.isBypassed(pkg)).isTrue()
        assertThat(OverlayManager.bypassReason(pkg)).isEqualTo(BlockReason.APP_BLOCKED)
        // Il cuore del fix: forzare un blocco di profilo non sospende il cap.
        assertThat(OverlayManager.isLimitBypassActive(pkg)).isFalse()
    }

    @Test
    fun usageLimitBypass_isLimitBypass() {
        OverlayManager.markBypassed(pkg, 5 * 60_000L, reason = BlockReason.USAGE_LIMIT)
        assertThat(OverlayManager.isLimitBypassActive(pkg)).isTrue()
    }

    @Test
    fun bypassExpiredExtension_isLimitBypass() {
        // L'estensione "+5 min" dal prompt BYPASS_EXPIRED discende dal limite.
        OverlayManager.markBypassed(pkg, 5 * 60_000L, reason = BlockReason.BYPASS_EXPIRED)
        assertThat(OverlayManager.isLimitBypassActive(pkg)).isTrue()
    }

    @Test
    fun defaultReason_isProfileBlock_notLimit() {
        // markBypassed senza reason esplicito ⇒ APP_BLOCKED ⇒ non è limit bypass.
        OverlayManager.markBypassed(pkg, 5 * 60_000L)
        assertThat(OverlayManager.isBypassed(pkg)).isTrue()
        assertThat(OverlayManager.isLimitBypassActive(pkg)).isFalse()
    }

    @Test
    fun expiredBypass_reportsNothing() {
        // Durata negativa ⇒ già scaduto: niente bypass, niente reason.
        OverlayManager.markBypassed(pkg, -1L, reason = BlockReason.USAGE_LIMIT)
        assertThat(OverlayManager.isBypassed(pkg)).isFalse()
        assertThat(OverlayManager.bypassReason(pkg)).isNull()
        assertThat(OverlayManager.isLimitBypassActive(pkg)).isFalse()
    }

    @Test
    fun clearBypass_removesState() {
        OverlayManager.markBypassed(pkg, 5 * 60_000L, reason = BlockReason.USAGE_LIMIT)
        OverlayManager.clearBypass(pkg)
        assertThat(OverlayManager.isBypassed(pkg)).isFalse()
        assertThat(OverlayManager.isLimitBypassActive(pkg)).isFalse()
    }

    @Test
    fun perDomainBypass_isScopedAndNotLimit() {
        OverlayManager.markBypassed(
            pkg,
            5 * 60_000L,
            domain = "reddit.com",
            reason = BlockReason.WEBSITE_BLOCKED,
        )
        assertThat(OverlayManager.isBypassed(pkg, "reddit.com")).isTrue()
        // Lo scope per-dominio non sblocca l'intera app...
        assertThat(OverlayManager.isBypassed(pkg)).isFalse()
        // ...e un bypass di sito non è mai un bypass del limite.
        assertThat(OverlayManager.isLimitBypassActive(pkg, "reddit.com")).isFalse()
    }

    @Test
    fun focusAndSectionReasons_areNotLimitBypass() {
        // Gli altri reason non-limite cadono nel ramo else di isLimitBypassActive.
        OverlayManager.markBypassed(pkg, 5 * 60_000L, reason = BlockReason.FOCUS_MODE)
        assertThat(OverlayManager.isLimitBypassActive(pkg)).isFalse()
        OverlayManager.markBypassed(pkg, 5 * 60_000L, reason = BlockReason.SECTION_BLOCKED)
        assertThat(OverlayManager.isLimitBypassActive(pkg)).isFalse()
    }

    @Test
    fun reMark_overwritesReason_lastWriteWins() {
        // L'utente forza prima un blocco di profilo, poi (stesso pkg) un blocco
        // di limite: l'ultimo grant determina il reason corrente.
        OverlayManager.markBypassed(pkg, 5 * 60_000L, reason = BlockReason.APP_BLOCKED)
        assertThat(OverlayManager.isLimitBypassActive(pkg)).isFalse()
        OverlayManager.markBypassed(pkg, 5 * 60_000L, reason = BlockReason.USAGE_LIMIT)
        assertThat(OverlayManager.isLimitBypassActive(pkg)).isTrue()
    }

    @Test
    fun clearBypass_alsoClearsPerDomainEntries() {
        // clearBypass azzera sia la chiave app-wide sia TUTTE le varianti
        // per-dominio (pkg|*) — esercita il prefix-scan.
        OverlayManager.markBypassed(pkg, 5 * 60_000L, reason = BlockReason.APP_BLOCKED)
        OverlayManager.markBypassed(pkg, 5 * 60_000L, domain = "reddit.com", reason = BlockReason.WEBSITE_BLOCKED)
        OverlayManager.markBypassed(pkg, 5 * 60_000L, domain = "x.com", reason = BlockReason.WEBSITE_BLOCKED)
        OverlayManager.clearBypass(pkg)
        assertThat(OverlayManager.isBypassed(pkg)).isFalse()
        assertThat(OverlayManager.isBypassed(pkg, "reddit.com")).isFalse()
        assertThat(OverlayManager.isBypassed(pkg, "x.com")).isFalse()
    }

    @Test
    fun perDomainKeys_areIsolatedFromEachOther() {
        // Un bypass su una chiave non "contagia" un'altra chiave (né un altro
        // dominio né l'app-wide).
        OverlayManager.markBypassed(pkg, 5 * 60_000L, domain = "a.com", reason = BlockReason.USAGE_LIMIT)
        assertThat(OverlayManager.isLimitBypassActive(pkg, "a.com")).isTrue()
        assertThat(OverlayManager.isLimitBypassActive(pkg, "b.com")).isFalse()
        assertThat(OverlayManager.isLimitBypassActive(pkg)).isFalse()
    }
}
