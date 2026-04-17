package com.dev.koru.strictmode

import android.content.Context
import android.provider.Settings
import java.security.MessageDigest
import java.util.Calendar

/**
 * Backdoor code per disattivare Strict Mode quando l'utente è in crisi.
 * Basato su device_id + week_of_year (quindi cambia ogni settimana, niente server).
 */
object BackdoorCodeGenerator {
    private const val SALT = "koru_strict_v1"

    fun generateCurrentCode(context: Context): String {
        val deviceId = getDeviceId(context)
        val weekKey = getCurrentWeekKey()
        val input = "$deviceId:$weekKey:$SALT"
        return sha256(input).substring(0, 8).uppercase()
    }

    fun validateCode(context: Context, code: String): Boolean {
        val expected = generateCurrentCode(context)
        return code.trim().uppercase() == expected
    }

    private fun getDeviceId(context: Context): String =
        Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown"

    private fun getCurrentWeekKey(): String {
        val cal = Calendar.getInstance()
        return "${cal.get(Calendar.YEAR)}-W${cal.get(Calendar.WEEK_OF_YEAR)}"
    }

    private fun sha256(input: String): String {
        val md = MessageDigest.getInstance("SHA-256")
        return md.digest(input.toByteArray()).joinToString("") { "%02x".format(it) }
    }
}
