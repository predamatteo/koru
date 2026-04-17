package com.dev.koru.strictmode

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

/**
 * Device Admin receiver per Koru Strict Mode.
 * Attivato dall'utente via Settings → Device admin apps.
 * Permette a Koru di bloccare disinstallazione e settings.
 */
class KoruDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence =
        "Disabling Device Admin will turn off Strict Mode. Are you sure?"
}
