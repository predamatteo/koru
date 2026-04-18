package com.dev.koru.overlay

import android.graphics.Color as AndroidColor
import android.util.Log
import org.json.JSONObject

/**
 * Config dell'overlay per-app-per-profilo. Parsato da
 * `app_profile_relations.overlay_config_json` popolato dal Flutter
 * OverlayDesignerScreen.
 *
 * Lo schema JSON è allineato a [lib/domain/entities/overlay_config.dart].
 */
data class OverlayConfig(
    val backgroundColorArgb: Int = 0xFFA85449.toInt(), // Koru danger
    val messageTitle: String? = null,
    val messageSubtitle: String? = null,
    val countdownSeconds: Int = 8,
    val shakeEnabled: Boolean = false,
    val allowBypassAfterCountdown: Boolean = true,
) {
    companion object {
        val DEFAULT = OverlayConfig()

        fun fromJsonString(json: String?): OverlayConfig {
            if (json.isNullOrBlank()) return DEFAULT
            return try {
                val obj = JSONObject(json)
                val hex = obj.optString("backgroundColorHex", "#A85449")
                val argb = parseHexToArgb(hex)
                OverlayConfig(
                    backgroundColorArgb = argb,
                    messageTitle = obj.optString("messageTitle", "").ifBlank { null },
                    messageSubtitle = obj.optString("messageSubtitle", "").ifBlank { null },
                    countdownSeconds = obj.optInt("countdownSeconds", 8),
                    shakeEnabled = obj.optBoolean("shakeEnabled", false),
                    allowBypassAfterCountdown =
                        obj.optBoolean("allowBypassAfterCountdown", true),
                )
            } catch (e: Exception) {
                Log.w("OverlayConfig", "Fallback to default, parse failed: ${e.message}")
                DEFAULT
            }
        }

        private fun parseHexToArgb(hex: String): Int {
            return try {
                AndroidColor.parseColor(if (hex.startsWith("#")) hex else "#$hex")
            } catch (_: Exception) {
                0xFFA85449.toInt()
            }
        }
    }
}

/**
 * Reason del blocco — determina copy e icon nella UI.
 */
enum class BlockReason {
    APP_BLOCKED,
    SECTION_BLOCKED,
    WEBSITE_BLOCKED,
    FOCUS_MODE,
}
