package com.dev.koru.service

import com.dev.koru.db.NativeProfile
import com.google.common.truth.Truth.assertThat
import org.json.JSONObject
import org.junit.Test

/**
 * Test PURI dei costruttori JSON di [BlockEventLogger] (la parte testabile del
 * bookkeeping verso l'event-channel Flutter). Il payload sul channel e' un
 * contratto cross-runtime (lo legge Dart): verifico che la forma sia IDENTICA
 * agli `sendBlockingStateEvent` / `sendSectionEvent` inline precedenti, incluso
 * il fallback `profileId=-1` / `profileTitle=""` per profilo null.
 *
 * Usa l'implementazione `org.json` reale (gia' testImplementation), senza
 * Robolectric: i builder sono funzioni pure.
 */
class BlockEventLoggerTest {

    private fun profile(id: Int, title: String) = NativeProfile(
        id = id,
        title = title,
        typeCombinations = 0,
        onConditions = 0,
        operator = 0,
        dayFlags = 0,
        blockNotifications = false,
        blockLaunch = false,
        isEnabled = true,
        isLocked = false,
        onUntil = 0L,
        lockedUntil = 0L,
        pausedUntil = 0L,
        blockingMode = 0,
        blockUnsupportedBrowsers = false,
        blockAdultContent = false,
        colorHex = "#5C8262",
        emoji = "E",
    )

    @Test
    fun blockingStateJson_withProfile_hasAllFields() {
        val json = JSONObject(
            BlockEventLogger.blockingStateJson(
                isBlocking = true,
                packageName = "com.instagram.android",
                profile = profile(7, "Lavoro"),
            ),
        )
        assertThat(json.getString("type")).isEqualTo("BLOCKING_STATE")
        assertThat(json.getBoolean("isBlocking")).isTrue()
        assertThat(json.getString("packageName")).isEqualTo("com.instagram.android")
        assertThat(json.getInt("profileId")).isEqualTo(7)
        assertThat(json.getString("profileTitle")).isEqualTo("Lavoro")
    }

    @Test
    fun blockingStateJson_nullProfile_usesFallbacks() {
        // Ramo "dismiss overlay" (Allow): sendBlockingStateEvent(false,"",null).
        val json = JSONObject(
            BlockEventLogger.blockingStateJson(
                isBlocking = false,
                packageName = "",
                profile = null,
            ),
        )
        assertThat(json.getString("type")).isEqualTo("BLOCKING_STATE")
        assertThat(json.getBoolean("isBlocking")).isFalse()
        assertThat(json.getString("packageName")).isEmpty()
        // Fallback storici per profilo null.
        assertThat(json.getInt("profileId")).isEqualTo(-1)
        assertThat(json.getString("profileTitle")).isEmpty()
    }

    @Test
    fun sectionJson_hasAllFields() {
        val json = JSONObject(
            BlockEventLogger.sectionJson(
                packageName = "com.google.android.youtube",
                sectionWireId = "shorts",
                profile = profile(3, "Focus"),
            ),
        )
        assertThat(json.getString("type")).isEqualTo("IN_APP_SECTION_DETECTED")
        assertThat(json.getString("packageName")).isEqualTo("com.google.android.youtube")
        assertThat(json.getString("section")).isEqualTo("shorts")
        assertThat(json.getInt("profileId")).isEqualTo(3)
        assertThat(json.getString("profileTitle")).isEqualTo("Focus")
    }
}
