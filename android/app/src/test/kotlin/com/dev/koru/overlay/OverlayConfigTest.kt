package com.dev.koru.overlay

import com.google.common.truth.Truth.assertThat
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Tests for [OverlayConfig] + [BlockReason].
 *
 * Robolectric is required: `parseHexToArgb` calls into
 * [android.graphics.Color.parseColor] which has no JVM fake without it.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class OverlayConfigTest {

    // -------- DEFAULT --------

    @Test
    fun default_hasKoruFelceColorAndExpectedFields() {
        val d = OverlayConfig.DEFAULT
        assertThat(d.backgroundColorArgb).isEqualTo(0xFF5C8262.toInt())
        assertThat(d.messageTitle).isNull()
        assertThat(d.messageSubtitle).isNull()
        assertThat(d.countdownSeconds).isEqualTo(8)
        assertThat(d.shakeEnabled).isFalse()
        assertThat(d.allowBypassAfterCountdown).isTrue()
    }

    // -------- fromJsonString — null/blank fallbacks --------

    @Test
    fun fromJsonString_null_returnsDefault() {
        assertThat(OverlayConfig.fromJsonString(null)).isEqualTo(OverlayConfig.DEFAULT)
    }

    @Test
    fun fromJsonString_empty_returnsDefault() {
        assertThat(OverlayConfig.fromJsonString("")).isEqualTo(OverlayConfig.DEFAULT)
    }

    @Test
    fun fromJsonString_blank_returnsDefault() {
        assertThat(OverlayConfig.fromJsonString("   ")).isEqualTo(OverlayConfig.DEFAULT)
    }

    @Test
    fun fromJsonString_malformedJson_returnsDefault() {
        assertThat(OverlayConfig.fromJsonString("{not json"))
            .isEqualTo(OverlayConfig.DEFAULT)
    }

    // -------- fromJsonString — happy path --------

    @Test
    fun fromJsonString_validJson_parsesAllFields() {
        val json = """
            {
              "backgroundColorHex":"#A85449",
              "messageTitle":"Pause",
              "messageSubtitle":"Take a breath",
              "countdownSeconds":12,
              "shakeEnabled":true,
              "allowBypassAfterCountdown":false
            }
        """.trimIndent()
        val cfg = OverlayConfig.fromJsonString(json)

        assertThat(cfg.backgroundColorArgb).isEqualTo(0xFFA85449.toInt())
        assertThat(cfg.messageTitle).isEqualTo("Pause")
        assertThat(cfg.messageSubtitle).isEqualTo("Take a breath")
        assertThat(cfg.countdownSeconds).isEqualTo(12)
        assertThat(cfg.shakeEnabled).isTrue()
        assertThat(cfg.allowBypassAfterCountdown).isFalse()
    }

    // -------- hex parsing edge cases --------

    @Test
    fun fromJsonString_hexWithoutHash_isPrefixed() {
        val json = """{"backgroundColorHex":"5C8262"}"""
        val cfg = OverlayConfig.fromJsonString(json)
        assertThat(cfg.backgroundColorArgb).isEqualTo(0xFF5C8262.toInt())
    }

    @Test
    fun fromJsonString_invalidHex_fallsBackToKoruFelce() {
        val json = """{"backgroundColorHex":"ZZZZZZ"}"""
        val cfg = OverlayConfig.fromJsonString(json)
        assertThat(cfg.backgroundColorArgb).isEqualTo(0xFF5C8262.toInt())
    }

    // -------- ifBlank handling for string fields --------

    @Test
    fun fromJsonString_emptyMessageTitle_returnsNull() {
        val json = """{"messageTitle":""}"""
        val cfg = OverlayConfig.fromJsonString(json)
        assertThat(cfg.messageTitle).isNull()
    }

    @Test
    fun fromJsonString_emptyMessageSubtitle_returnsNull() {
        val json = """{"messageSubtitle":""}"""
        val cfg = OverlayConfig.fromJsonString(json)
        assertThat(cfg.messageSubtitle).isNull()
    }

    @Test
    fun fromJsonString_omittedFields_useDataClassDefaults() {
        // Empty object → only the static "#5C8262" default for hex is parsed;
        // other fields keep their data-class defaults.
        val cfg = OverlayConfig.fromJsonString("{}")
        assertThat(cfg.backgroundColorArgb).isEqualTo(0xFF5C8262.toInt())
        assertThat(cfg.messageTitle).isNull()
        assertThat(cfg.messageSubtitle).isNull()
        assertThat(cfg.countdownSeconds).isEqualTo(8)
        assertThat(cfg.shakeEnabled).isFalse()
        assertThat(cfg.allowBypassAfterCountdown).isTrue()
    }

    // -------- BlockReason enum --------

    @Test
    fun blockReason_hasSixValuesInExpectedOrder() {
        // Six values: APP_BLOCKED, SECTION_BLOCKED, WEBSITE_BLOCKED,
        // FOCUS_MODE, USAGE_LIMIT, BYPASS_EXPIRED.
        assertThat(BlockReason.values()).asList().containsExactly(
            BlockReason.APP_BLOCKED,
            BlockReason.SECTION_BLOCKED,
            BlockReason.WEBSITE_BLOCKED,
            BlockReason.FOCUS_MODE,
            BlockReason.USAGE_LIMIT,
            BlockReason.BYPASS_EXPIRED,
        ).inOrder()
    }

    @Test
    fun blockReason_valueOf_roundTrips() {
        BlockReason.values().forEach { reason ->
            assertThat(BlockReason.valueOf(reason.name)).isEqualTo(reason)
        }
    }
}
