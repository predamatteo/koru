package com.dev.koru.strictmode

import android.content.Context
import android.util.Log
import java.io.File

/**
 * File-based cross-process store per il mask delle opzioni Strict Mode.
 * Sia il main process che il processo :accessibility leggono/scrivono questo
 * file (in filesDir, accessibile a tutti i processi dell'app).
 */
object StrictModeStore {
    private const val TAG = "StrictModeStore"
    private const val FILE_NAME = "koru_strict_mask.txt"

    fun saveMask(context: Context, mask: Int) {
        try {
            val file = File(context.filesDir, FILE_NAME)
            file.writeText(mask.toString())
            Log.d(TAG, "Saved strict mode mask: $mask")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save mask", e)
        }
    }

    fun readMask(context: Context): Int {
        return try {
            val file = File(context.filesDir, FILE_NAME)
            if (!file.exists()) return 0
            val text = file.readText().trim()
            text.toIntOrNull() ?: 0
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read mask", e)
            0
        }
    }
}
