package com.dev.koru.channels

import android.app.Activity
import android.app.LocaleManager
import android.content.Intent
import android.os.Build
import android.os.LocaleList
import android.util.Log
import com.dev.koru.service.UiSettingsStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object ProfileMethodChannel {
    private const val TAG = "ProfileMethodChannel"
    private const val CHANNEL = "com.koru/profiles"
    const val ACTION_RELOAD_PROFILES = "com.dev.koru.ACTION_RELOAD_PROFILES"

    private var activityRef: Activity? = null

    fun register(flutterEngine: FlutterEngine, activity: Activity) {
        activityRef = activity
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "notifyProfileChanged" -> {
                        val profileId = call.argument<Int>("profileId") ?: -1
                        Log.d(TAG, "Profile changed: $profileId")
                        reloadServiceProfiles()
                        result.success(null)
                    }
                    "notifyProfileToggled" -> {
                        val profileId = call.argument<Int>("profileId") ?: -1
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        Log.d(TAG, "Profile toggled: $profileId -> $enabled")
                        reloadServiceProfiles()
                        result.success(null)
                    }
                    "setProfilePaused" -> {
                        reloadServiceProfiles()
                        result.success(null)
                    }
                    "syncAll" -> {
                        reloadServiceProfiles()
                        result.success(null)
                    }
                    "setActiveFontId" -> {
                        // Preferenza UI globale (font scelto in-app) → store
                        // cross-process letto dall'overlay nel processo
                        // :accessibility. Nessun reload profili necessario.
                        val fontId = call.argument<Int>("fontId") ?: 0
                        activityRef?.let {
                            UiSettingsStore.setActiveFontId(it.applicationContext, fontId)
                        }
                        Log.d(TAG, "Active font id set: $fontId")
                        result.success(null)
                    }
                    "setAppLocale" -> {
                        val tag = call.argument<String>("languageTag").orEmpty()
                        applyAppLocale(tag)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Applica la lingua scelta in-app come per-app locale di Android, così
    /// tutto ciò che è nativo e rivolto all'utente — overlay di blocco,
    /// notifica del foreground service, widget home — risolve `res/values*`
    /// nella stessa lingua della UI Flutter.
    ///
    /// [languageTag] è un BCP-47 (`it`, `en`); stringa vuota = torna al locale
    /// di sistema. Su API < 33 `LocaleManager` non esiste e la funzione è una
    /// no-op: Hive resta la fonte di verità per Flutter e il native segue il
    /// sistema (degradazione dichiarata, vedi `locale_provider.dart`).
    private fun applyAppLocale(languageTag: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            Log.d(TAG, "setAppLocale('$languageTag') ignored: API < 33")
            return
        }
        val ctx = activityRef ?: return
        try {
            val manager = ctx.getSystemService(LocaleManager::class.java) ?: return
            val desired = if (languageTag.isEmpty()) {
                LocaleList.getEmptyLocaleList()
            } else {
                LocaleList.forLanguageTags(languageTag)
            }
            // setApplicationLocales ricrea l'Activity. Con lo stesso valore è
            // già una no-op lato sistema, ma il confronto esplicito tiene la
            // ri-asserzione all'avvio (`syncToNative`) gratuita e rende
            // impossibile un ciclo ricreazione → sync → ricreazione.
            if (manager.applicationLocales == desired) {
                Log.d(TAG, "App locale already '$languageTag', nothing to do")
                return
            }
            manager.applicationLocales = desired
            Log.d(TAG, "App locale set to '$languageTag'")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set app locale '$languageTag'", e)
        }
    }

    private fun reloadServiceProfiles() {
        val ctx = activityRef ?: return
        try {
            val intent = Intent(ACTION_RELOAD_PROFILES).apply {
                setPackage(ctx.packageName)
            }
            ctx.sendBroadcast(intent)
            Log.d(TAG, "Sent RELOAD_PROFILES broadcast")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send reload broadcast", e)
        }
    }
}
