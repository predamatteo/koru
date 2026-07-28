package com.dev.koru.service

import android.content.ComponentName
import android.content.Context
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.SystemClock
import com.dev.koru.diagnostics.BlackBox
import com.dev.koru.notification.KoruNotificationListenerService

/**
 * Layer "chirurgico" del silenziamento: mette in pausa la MediaSession del
 * package bloccato, e solo quella.
 *
 * ## Perche' e' meglio dell'audio focus
 * L'audio focus non e' targettizzato: chiederlo zittisce chiunque stia
 * riproducendo, quindi bloccare Instagram mentre l'utente ascolta Spotify mette
 * in pausa anche Spotify. Qui invece parliamo direttamente al controller del
 * package bloccato: zero danno collaterale, e la ripresa dopo "Apri comunque"
 * e' un comando esplicito invece di una speranza sulla buona educazione del
 * player.
 *
 * ## Perche' resta un layer OPZIONALE
 * Serve l'accesso alle notifiche. Koru **non lo chiede apposta**: il permesso e
 * il [KoruNotificationListenerService] esistono gia' per il filtro notifiche, e
 * qui li riusiamo se l'utente li ha gia' concessi. Se non ci sono,
 * `getActiveSessions` lancia `SecurityException`, questo port riporta `false` e
 * il [MediaSilencer] ripiega sull'audio focus — che funziona da solo.
 *
 * Copertura reale: YouTube pubblica sempre una MediaSession; Instagram e TikTok
 * spesso no, e per loro lavora il fallback.
 */
class AndroidMediaSessionPort(private val context: Context) : MediaSessionPort {

    private companion object {
        /// TTL della cache del permesso. `Settings.Secure` e' una query IPC e
        /// il silenziamento la interrogherebbe a ogni sonda, sul main thread
        /// nel path di blocco (gia' sensibile — vedi il tag A11Y-FLASH). Il
        /// permesso cambia solo quando l'utente va nelle impostazioni, quindi
        /// 30s di staleness sono ampiamente accettabili.
        const val ACCESS_CACHE_TTL_MS = 30_000L
    }

    private var accessCachedAtMs = 0L
    private var accessGranted = false

    override fun pause(packageName: String): Boolean {
        var paused = false
        controllersFor(packageName).forEach { c ->
            try {
                // SOLO se sta davvero riproducendo. Pausare una sessione gia'
                // ferma la marcherebbe come "messa in pausa da noi", e al
                // bypass emetteremmo un play() che avvia una riproduzione che
                // l'utente non aveva mai avviato.
                val state = c.playbackState?.state
                if (state == PlaybackState.STATE_PLAYING ||
                    state == PlaybackState.STATE_BUFFERING
                ) {
                    c.transportControls.pause()
                    paused = true
                }
            } catch (e: Exception) {
                BlackBox.log(MediaSilencer.TAG, "pause sessione $packageName fallita: ${e.message}")
            }
        }
        return paused
    }

    override fun play(packageName: String): Boolean {
        var resumed = false
        controllersFor(packageName).forEach { c ->
            try {
                c.transportControls.play()
                resumed = true
            } catch (e: Exception) {
                BlackBox.log(MediaSilencer.TAG, "play sessione $packageName fallito: ${e.message}")
            }
        }
        return resumed
    }

    private fun controllersFor(packageName: String): List<MediaController> {
        if (!isNotificationAccessGranted()) return emptyList()
        val msm = context.getSystemService(Context.MEDIA_SESSION_SERVICE)
            as? MediaSessionManager ?: return emptyList()
        return try {
            msm.getActiveSessions(
                ComponentName(context, KoruNotificationListenerService::class.java),
            ).filter { it.packageName == packageName }
        } catch (e: SecurityException) {
            // Accesso revocato fra il check e la chiamata: degrada al focus.
            BlackBox.log(MediaSilencer.TAG, "getActiveSessions negato: ${e.message}")
            accessGranted = false
            emptyList()
        } catch (e: Exception) {
            BlackBox.log(MediaSilencer.TAG, "getActiveSessions ha lanciato: ${e.message}")
            emptyList()
        }
    }

    /// True se l'utente ha concesso l'accesso alle notifiche a Koru. Stessa
    /// query di `NotificationFilterCallHandler.isNotificationAccessGranted`,
    /// qui con cache perche' sta su un path caldo.
    private fun isNotificationAccessGranted(): Boolean {
        val now = SystemClock.elapsedRealtime()
        if (now - accessCachedAtMs < ACCESS_CACHE_TTL_MS) return accessGranted
        accessCachedAtMs = now
        accessGranted = try {
            val flat = android.provider.Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners",
            ) ?: ""
            val expected = ComponentName(
                context,
                KoruNotificationListenerService::class.java,
            ).flattenToString()
            flat.contains(expected)
        } catch (e: Exception) {
            false
        }
        return accessGranted
    }
}
