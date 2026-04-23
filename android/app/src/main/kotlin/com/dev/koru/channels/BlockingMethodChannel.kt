package com.dev.koru.channels

import android.app.Activity
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import com.dev.koru.notification.NotificationFilterStore
import com.dev.koru.service.AppUsageLimitsStore
import com.dev.koru.service.LockForegroundService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/// Dart `int` piccoli (fino a ~2.1B) entrano nel MethodChannel come Integer;
/// valori più grandi (es. timestamps) come Long. `call.argument<Long>` fa
/// un cast runtime che CRASHA se il valore arriva come Integer. Questo
/// helper gestisce entrambi in modo safe.
private fun MethodCall.longArg(name: String): Long = when (val v = argument<Any>(name)) {
    is Long -> v
    is Int -> v.toLong()
    is Number -> v.toLong()
    else -> 0L
}

object BlockingMethodChannel {
    private const val CHANNEL = "com.koru/blocking"

    fun register(flutterEngine: FlutterEngine, activity: Activity) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startBlockingService" -> {
                        try {
                            val intent = Intent(activity, LockForegroundService::class.java).apply {
                                action = LockForegroundService.ACTION_START
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                activity.startForegroundService(intent)
                            } else {
                                activity.startService(intent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SERVICE_START_FAILED", e.message, null)
                        }
                    }
                    "stopBlockingService" -> {
                        val intent = Intent(activity, LockForegroundService::class.java).apply {
                            action = LockForegroundService.ACTION_STOP
                        }
                        activity.startService(intent)
                        result.success(true)
                    }
                    "isBlockingServiceRunning" -> result.success(LockForegroundService.isRunning)
                    "getInstalledApps" -> result.success(getInstalledApps(activity))
                    "getUsageStats" -> {
                        val startMs = call.longArg("startMs")
                        val endMs = call.longArg("endMs").takeIf { it > 0 }
                            ?: System.currentTimeMillis()
                        result.success(getUsageStats(activity, startMs, endMs))
                    }
                    "startQuickBlock" -> {
                        val durationMs = call.longArg("durationMs")
                        val whitelist = (call.argument<List<String>>("whitelist") ?: emptyList())
                            .toSet()
                        // Il context va attaccato anche se il service non è
                        // mai stato istanziato: serve per persistere lo
                        // snapshot letto dal processo :accessibility.
                        LockForegroundService.quickBlockManager.attachContext(activity.applicationContext)
                        LockForegroundService.quickBlockManager.startQuickBlock(
                            durationMs,
                            whitelist,
                        )
                        result.success(true)
                    }
                    "stopQuickBlock" -> {
                        LockForegroundService.quickBlockManager.stop()
                        result.success(true)
                    }
                    "startPomodoro" -> {
                        val workMs = call.longArg("workMs")
                        val breakMs = call.longArg("breakMs")
                        val cycles = call.argument<Int>("cycles") ?: 4
                        val whitelist = (call.argument<List<String>>("whitelist") ?: emptyList())
                            .toSet()
                        LockForegroundService.quickBlockManager.attachContext(activity.applicationContext)
                        LockForegroundService.quickBlockManager.startPomodoro(
                            workMs,
                            breakMs,
                            cycles,
                            whitelist,
                        )
                        result.success(true)
                    }
                    "stopPomodoro" -> {
                        LockForegroundService.quickBlockManager.stop()
                        result.success(true)
                    }
                    "launchApp" -> {
                        val pkg = call.argument<String>("packageName") ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        val intent = activity.packageManager.getLaunchIntentForPackage(pkg)
                        if (intent != null) {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            activity.startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "uninstallApp" -> {
                        val pkg = call.argument<String>("packageName") ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        try {
                            val intent = Intent(Intent.ACTION_DELETE).apply {
                                data = android.net.Uri.parse("package:$pkg")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            activity.startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UNINSTALL_FAILED", e.message, null)
                        }
                    }
                    "openAppInfo" -> {
                        val pkg = call.argument<String>("packageName") ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = android.net.Uri.parse("package:$pkg")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            activity.startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("APP_INFO_FAILED", e.message, null)
                        }
                    }
                    "getBatteryLevel" -> {
                        val bm = activity.getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
                        result.success(bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY))
                    }
                    "isCharging" -> {
                        val bm = activity.getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
                        result.success(bm.isCharging)
                    }
                    "getDefaultDialerPackage" -> {
                        result.success(resolveDefaultDialer(activity))
                    }
                    "getDefaultCameraPackage" -> {
                        result.success(resolveDefaultCamera(activity))
                    }
                    "getAppDailyLimits" -> {
                        result.success(AppUsageLimitsStore.read(activity.applicationContext))
                    }
                    "setAppDailyLimits" -> {
                        @Suppress("UNCHECKED_CAST")
                        val raw = call.argument<Map<String, Any>>("limits") ?: emptyMap()
                        val parsed = raw.mapValues { (it.value as? Number)?.toInt() ?: 0 }
                        AppUsageLimitsStore.save(activity.applicationContext, parsed)
                        result.success(true)
                    }
                    "getUsageTodayMs" -> {
                        val pkg = call.argument<String>("packageName")
                            ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        result.success(getTodayForegroundMs(activity, pkg))
                    }
                    "getSilencedPackages" -> {
                        result.success(
                            NotificationFilterStore.read(activity.applicationContext).toList()
                        )
                    }
                    "setSilencedPackages" -> {
                        val list = call.argument<List<String>>("packages") ?: emptyList()
                        NotificationFilterStore.save(activity.applicationContext, list.toSet())
                        result.success(true)
                    }
                    "isNotificationAccessGranted" -> {
                        val flat = android.provider.Settings.Secure.getString(
                            activity.contentResolver,
                            "enabled_notification_listeners",
                        ) ?: ""
                        val expected = "${activity.packageName}/" +
                            "com.dev.koru.notification.KoruNotificationListenerService"
                        result.success(flat.contains(expected))
                    }
                    "openNotificationAccessSettings" -> {
                        val ok = openNotificationAccessSettings(activity)
                        result.success(ok)
                    }
                    "getCurrentWifiSsid" -> {
                        result.success(getCurrentWifiSsid(activity))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getInstalledApps(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        return pm.getInstalledApplications(PackageManager.GET_META_DATA)
            .filter {
                it.flags and ApplicationInfo.FLAG_SYSTEM == 0 ||
                    pm.getLaunchIntentForPackage(it.packageName) != null
            }
            .map { app ->
                mapOf(
                    "packageName" to app.packageName,
                    "label" to (pm.getApplicationLabel(app)?.toString() ?: app.packageName),
                    "icon" to try { drawableToBytes(pm.getApplicationIcon(app)) } catch (_: Exception) { null },
                )
            }
            .sortedBy { (it["label"] as String).lowercase() }
    }

    private fun getUsageStats(context: Context, startMs: Long, endMs: Long): List<Map<String, Any>> {
        val totals = computeForegroundMsPerPackage(context, startMs, endMs)
        val lastUsed = queryLastTimeUsedPerPackage(context, startMs, endMs)
        return totals.entries
            .filter { it.value > 0 }
            .map { (pkg, ms) ->
                mapOf(
                    "packageName" to pkg,
                    "totalTimeMs" to ms,
                    "lastTimeUsed" to (lastUsed[pkg] ?: 0L),
                )
            }
    }

    /// Tempo oggi in foreground per `pkg` (dalla mezzanotte locale).
    private fun getTodayForegroundMs(context: Context, pkg: String): Long {
        val cal = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val from = cal.timeInMillis
        val now = System.currentTimeMillis()
        return try {
            computeForegroundMsPerPackage(context, from, now)[pkg] ?: 0L
        } catch (_: Exception) { 0L }
    }

    /// Calcola il tempo in foreground (ms) per ogni package nella finestra
    /// [startMs, endMs] usando `queryEvents` e una state machine
    /// RESUMED (1) / PAUSED (2) / STOPPED (23).
    ///
    /// Algoritmo portato da minimalist_phone (decompiled: a.java:323-397)
    /// dopo aver osservato sotto-conteggi fino a ~30 minuti con il
    /// pairing naive RESUMED→(PAUSED|STOPPED):
    ///
    /// 1. **Sort per-pkg per timestamp**: `queryEvents()` NON garantisce
    ///    l'ordine stretto dei ts sugli OEM customizzati (MIUI, ColorOS,
    ///    One UI). Eventi fuori ordine causavano pairing sbagliato e
    ///    sessioni perse. Minimalist_phone risolve raggruppando per
    ///    pkg e sortando prima del pairing.
    ///
    /// 2. **STOPPED non chiude la sessione**: nei casi Activity multi-step
    ///    (Chrome tabs, app con splash, giochi con ads) STOPPED può
    ///    arrivare dell'Activity PRECEDENTE dopo che una nuova Activity
    ///    dello stesso pkg è già RESUMED. Se lo uso per chiudere sessioni,
    ///    conto tempo sbagliato o pairing sbagliato. Invece lo salvo come
    ///    fallback per chiudere sessioni dove PAUSED manca proprio.
    ///
    /// 3. **Nuovo RESUMED con sessione aperta**: chiude con lo STOPPED
    ///    intermedio (se presente), NON col ts del nuovo RESUMED. Evita
    ///    di contare come "usage" il gap tra due RESUMED consecutivi
    ///    quando Android perde il PAUSED intermedio.
    ///
    /// Perché non usare `queryUsageStats().totalTimeInForeground`:
    /// - Instagram e app "social" triggerano overlay (PiP, notifiche,
    ///   stories) che NON sempre generano il MOVE_TO_BACKGROUND event;
    ///   il counter interno di Android si gonfia e non torna mai indietro.
    /// - `queryUsageStats(INTERVAL_DAILY)` può restituire più bucket per
    ///   lo stesso giorno (dopo reboot, cambio timezone), double-count.
    /// - `totalTimeInForeground` riflette il bucket intero, non la finestra.
    private fun computeForegroundMsPerPackage(
        context: Context,
        startMs: Long,
        endMs: Long,
    ): Map<String, Long> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE)
            as? UsageStatsManager ?: return emptyMap()
        // Query da 24h prima di startMs per catturare sessioni ancora aperte
        // all'inizio della finestra (app aperta dalle 22:00 di ieri chiusa
        // alle 00:30 di oggi). Lo span viene clippato a [startMs, endMs].
        val queryStart = startMs - 24L * 60 * 60 * 1000
        val events = try {
            usm.queryEvents(queryStart, endMs)
        } catch (_: Exception) { return emptyMap() }

        // Raccogli eventi rilevanti per package.
        val byPkg = HashMap<String, ArrayList<LongArray>>()
        val ev = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(ev)
            val pkg = ev.packageName ?: continue
            val type = ev.eventType
            if (type != UsageEvents.Event.MOVE_TO_FOREGROUND &&
                type != UsageEvents.Event.MOVE_TO_BACKGROUND &&
                type != 23
            ) continue
            byPkg.getOrPut(pkg) { ArrayList() }
                .add(longArrayOf(ev.timeStamp, type.toLong()))
        }

        val totals = HashMap<String, Long>()
        val now = System.currentTimeMillis()
        val windowClose = minOf(endMs, now)

        for ((pkg, list) in byPkg) {
            // Sort esplicito per timestamp — queryEvents non lo garantisce
            // su tutti i device (soprattutto dopo reboot o cambio clock).
            list.sortBy { it[0] }

            var resumeTs = 0L
            var pausedTs = 0L
            var stoppedTs = 0L
            var total = 0L

            for (item in list) {
                val ts = item[0]
                when (item[1].toInt()) {
                    UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                        // Sessione precedente ancora aperta + STOPPED
                        // intermedio → chiudi con STOPPED (PAUSED perso).
                        if (resumeTs != 0L && stoppedTs > resumeTs) {
                            total += clippedSpan(resumeTs, stoppedTs, startMs, endMs)
                            resumeTs = 0L
                        }
                        // Accetta RESUMED solo se non c'è sessione aperta
                        // o se il ts è più recente dell'ultimo PAUSED.
                        // Senza questa guardia, due RESUMED consecutivi
                        // (event loss) porterebbero a conteggi errati.
                        if (resumeTs == 0L || ts > pausedTs) {
                            resumeTs = ts
                        }
                    }
                    UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                        if (resumeTs != 0L) {
                            pausedTs = ts
                        }
                    }
                    23 -> {
                        // STOPPED solo tracciato: non chiude la sessione,
                        // serve come fallback per il prossimo RESUMED.
                        stoppedTs = ts
                    }
                }
                // Sessione completa: accumula span clippato.
                if (resumeTs != 0L && pausedTs != 0L) {
                    total += clippedSpan(resumeTs, pausedTs, startMs, endMs)
                    resumeTs = 0L
                    pausedTs = 0L
                }
            }
            // Sessione ancora aperta al termine (utente sta usando l'app
            // adesso, oppure evento PAUSED non è mai arrivato).
            if (resumeTs != 0L) {
                total += clippedSpan(resumeTs, windowClose, startMs, endMs)
            }

            if (total > 0) totals[pkg] = total
        }

        return totals
    }

    private fun clippedSpan(
        from: Long,
        to: Long,
        windowStart: Long,
        windowEnd: Long,
    ): Long {
        val s = maxOf(from, windowStart)
        val e = minOf(to, windowEnd)
        return (e - s).coerceAtLeast(0)
    }

    /// Ultima volta in cui ciascun package è stato visto come evento
    /// RESUMED/PAUSED nella finestra. Usato per l'UI "lastTimeUsed".
    private fun queryLastTimeUsedPerPackage(
        context: Context,
        startMs: Long,
        endMs: Long,
    ): Map<String, Long> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE)
            as? UsageStatsManager ?: return emptyMap()
        return try {
            usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startMs, endMs)
                .groupBy { it.packageName }
                .mapValues { (_, list) -> list.maxOf { it.lastTimeUsed } }
        } catch (_: Exception) { emptyMap() }
    }

    /// Apre le Settings di "Notification access" con fallback robusto:
    /// prima prova il deep-link diretto al component di Koru
    /// (ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS, API 30+), poi
    /// la action generica, poi Settings root. Ciascun tentativo è
    /// wrapped in try/catch per evitare crash su device dove l'intent
    /// non è disponibile o è bloccato da policy OEM.
    private fun openNotificationAccessSettings(activity: Activity): Boolean {
        val component = android.content.ComponentName(
            activity.packageName,
            "com.dev.koru.notification.KoruNotificationListenerService",
        )

        // Tentativo 1: deep-link al detail (Android 11+).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val intent = Intent(
                    android.provider.Settings
                        .ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS,
                )
                    .putExtra(
                        android.provider.Settings
                            .EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                        component.flattenToString(),
                    )
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(intent)
                return true
            } catch (_: Exception) {}
        }

        // Tentativo 2: lista generica di notification listeners.
        try {
            val intent = Intent(
                android.provider.Settings
                    .ACTION_NOTIFICATION_LISTENER_SETTINGS,
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            return true
        } catch (_: Exception) {}

        // Fallback finale: Settings root.
        try {
            val intent = Intent(android.provider.Settings.ACTION_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            return true
        } catch (_: Exception) {}
        return false
    }

    /// Legge il SSID della rete WiFi corrente. Su Android 10+ richiede
    /// ACCESS_FINE_LOCATION; se permesso non concesso ritorna null o
    /// "<unknown ssid>". L'UI gestisce la degradazione gentilmente.
    private fun getCurrentWifiSsid(context: Context): String? {
        return try {
            val wm = context.applicationContext
                .getSystemService(Context.WIFI_SERVICE) as? android.net.wifi.WifiManager
            val info = wm?.connectionInfo ?: return null
            val ssid = info.ssid
            if (ssid == null || ssid == "<unknown ssid>") return null
            // SSID è restituito wrapped tra virgolette.
            if (ssid.length >= 2 && ssid.startsWith("\"") && ssid.endsWith("\"")) {
                ssid.substring(1, ssid.length - 1)
            } else {
                ssid
            }
        } catch (_: Exception) {
            null
        }
    }

    /// Risolve il package del dialer di sistema (telecom + fallback su
     /// Intent.ACTION_DIAL se TelecomManager non disponibile).
    private fun resolveDefaultDialer(context: Context): String? {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val tm = context.getSystemService(Context.TELECOM_SERVICE)
                    as? android.telecom.TelecomManager
                val pkg = tm?.defaultDialerPackage
                if (!pkg.isNullOrBlank()) return pkg
            }
        } catch (_: Exception) {}
        val intent = Intent(Intent.ACTION_DIAL)
        val ri = context.packageManager.resolveActivity(intent, 0)
        return ri?.activityInfo?.packageName
    }

    /// Risolve l'app fotocamera di default (IMAGE_CAPTURE).
    private fun resolveDefaultCamera(context: Context): String? {
        val intent = Intent(android.provider.MediaStore.ACTION_IMAGE_CAPTURE)
        val ri = context.packageManager.resolveActivity(intent, 0)
        return ri?.activityInfo?.packageName
    }

    private fun drawableToBytes(drawable: Drawable): ByteArray {
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            drawable.bitmap
        } else {
            Bitmap.createBitmap(
                drawable.intrinsicWidth.coerceAtLeast(1),
                drawable.intrinsicHeight.coerceAtLeast(1),
                Bitmap.Config.ARGB_8888
            ).also {
                val canvas = Canvas(it)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
            }
        }
        val scaled = Bitmap.createScaledBitmap(bitmap, 96, 96, true)
        return ByteArrayOutputStream()
            .also { scaled.compress(Bitmap.CompressFormat.PNG, 100, it) }
            .toByteArray()
    }
}
