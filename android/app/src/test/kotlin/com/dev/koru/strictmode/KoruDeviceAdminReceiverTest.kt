package com.dev.koru.strictmode

import android.app.admin.DeviceAdminReceiver
import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Smoke tests for [KoruDeviceAdminReceiver].
 *
 * The lifecycle callbacks `onEnabled` / `onDisabled` / `onDisableRequested`
 * are driven by the system DevicePolicyManager and require a device profile
 * to invoke meaningfully. Here we only verify the class shape: extends
 * [DeviceAdminReceiver] and exposes the [KoruDeviceAdminReceiver.EXTRA_REQUIRE_BACKDOOR_CODE]
 * intent extra used by `MainActivity` to open the backdoor dialog.
 */
class KoruDeviceAdminReceiverTest {

    @Test
    fun classExtendsDeviceAdminReceiver() {
        assertThat(DeviceAdminReceiver::class.java.isAssignableFrom(KoruDeviceAdminReceiver::class.java))
            .isTrue()
    }

    @Test
    fun extraRequireBackdoorCode_hasExpectedValue() {
        assertThat(KoruDeviceAdminReceiver.EXTRA_REQUIRE_BACKDOOR_CODE)
            .isEqualTo("require_backdoor_code")
    }

    @Test
    fun receiverInstantiates() {
        // Default constructor must succeed: AndroidManifest registers the
        // receiver and the framework instantiates it via reflection.
        val r = KoruDeviceAdminReceiver()
        assertThat(r).isInstanceOf(DeviceAdminReceiver::class.java)
    }
}
