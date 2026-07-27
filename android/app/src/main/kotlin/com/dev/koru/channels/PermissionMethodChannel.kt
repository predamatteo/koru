package com.dev.koru.channels

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Activity
import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Rect
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import com.dev.koru.service.LauncherRecentsGate
import com.dev.koru.service.OpenAppsTracker
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object PermissionMethodChannel {
    private const val CHANNEL = "com.koru/permissions"

    /// Componenti Koru usati per il deep-link alle pagine di sistema
    /// per-servizio (accessibilità e notification listener).
    private const val ACCESSIBILITY_COMPONENT =
        "com.dev.koru.service.KoruAccessibilityService"
    private const val NOTIFICATION_LISTENER_COMPONENT =
        "com.dev.koru.notification.KoruNotificationListenerService"

    /// Extra non documentati ma stabili da anni nell'app Settings AOSP (e
    /// rispettati da Samsung/OnePlus/Xiaomi): fanno aprire la lista già
    /// scrollata sulla riga indicata, evidenziandola. Chi non li supporta li
    /// ignora e mostra la lista normale — mai peggio del comportamento base.
    private const val EXTRA_FRAGMENT_ARG_KEY = ":settings:fragment_args_key"
    private const val EXTRA_SHOW_FRAGMENT_ARGS = ":settings:show_fragment_args"

    /// Pagina di dettaglio del singolo servizio di accessibilità, esposta
    /// dall'app Settings da Android 14. La costante `Settings.ACTION_*`
    /// corrispondente è `@hide` (non compila con compileSdk 36), ma l'action
    /// string è quella dichiarata nell'intent-filter: se il device non la
    /// espone `startActivity` solleva ActivityNotFoundException e la cascata
    /// di [openAccessibilitySettings] ripiega sulla lista.
    private const val ACTION_ACCESSIBILITY_DETAILS_SETTINGS =
        "android.settings.ACCESSIBILITY_DETAILS_SETTINGS"
    private const val EXTRA_COMPONENT_NAME = "android.intent.extra.COMPONENT_NAME"

    private const val PERMISSION_POST_NOTIFICATIONS =
        "android.permission.POST_NOTIFICATIONS"
    private const val REQ_POST_NOTIFICATIONS = 4711

    /// Result Flutter in attesa della risposta al dialog di POST_NOTIFICATIONS.
    /// Risolto da [onRequestPermissionsResult], inoltrato da MainActivity.
    private var pendingNotificationResult: MethodChannel.Result? = null

    fun register(flutterEngine: FlutterEngine, activity: Activity) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkAccessibilityService" -> result.success(isAccessibilityEnabled(activity))
                    "openAccessibilitySettings" -> {
                        openAccessibilitySettings(activity)
                        result.success(null)
                    }
                    "checkUsageStatsPermission" -> result.success(hasUsageStats(activity))
                    "openUsageStatsSettings" -> {
                        openUsageStatsSettings(activity)
                        result.success(null)
                    }
                    "checkOverlayPermission" -> result.success(Settings.canDrawOverlays(activity))
                    "openOverlaySettings" -> {
                        openOverlaySettings(activity)
                        result.success(null)
                    }
                    "checkBatteryOptimization" -> {
                        val pm = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(activity.packageName))
                    }
                    "requestDisableBatteryOptimization" -> {
                        openBatteryOptimizationSettings(activity)
                        result.success(null)
                    }
                    "checkNotificationListener" -> result.success(isNotificationListenerEnabled(activity))
                    "openNotificationListenerSettings" -> {
                        openNotificationListenerSettings(activity)
                        result.success(null)
                    }
                    "checkNotificationPermission" -> result.success(areNotificationsEnabled(activity))
                    "requestNotificationPermission" -> requestNotificationPermission(activity, result)
                    "openAppNotificationSettings" -> {
                        openAppNotificationSettings(activity)
                        result.success(null)
                    }
                    "isDefaultLauncher" -> result.success(isDefaultLauncher(activity))
                    "openDefaultLauncherSettings" -> {
                        openDefaultLauncherSettings(activity)
                        result.success(null)
                    }
                    "setLauncherModeEnabled" -> {
                        // MainActivity ora ha HOME filter sempre enabled (no
                        // più activity-alias). Il toggle apre il picker di
                        // sistema per impostare Koru come default launcher.
                        openDefaultLauncherSettings(activity)
                        result.success(true)
                    }
                    "isLauncherModeEnabled" -> {
                        // "Enabled" = Koru è effettivamente il default launcher.
                        result.success(isDefaultLauncher(activity))
                    }
                    "setLauncherGestureExclusion" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        setLauncherGestureExclusion(activity, enabled)
                        result.success(null)
                    }
                    "setLauncherRecentsShield" -> {
                        // Blocco della gesture recents scopato al launcher:
                        // cavalca lo stesso lifecycle RouteAware dell'esclusione
                        // gesture (LauncherHomeScreen._setLauncherActive).
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        LauncherRecentsGate.setShieldActive(enabled)
                        if (enabled) {
                            // Prewarm anticipato della label map: shield ON =
                            // launcher in cima = recents apribili a breve. A
                            // freddo il prewarm (query PM + loadLabel) può
                            // superare i ~650ms di vita delle recents VUOTE:
                            // partire solo all'apertura della sessione brucia
                            // il burst iniziale. Idempotente e off-main.
                            OpenAppsTracker.prewarmLabelMap(activity.applicationContext)
                        }
                        result.success(null)
                    }
                    "checkAllPermissions" -> {
                        val pm = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(
                            mapOf(
                                "accessibility" to isAccessibilityEnabled(activity),
                                "usageStats" to hasUsageStats(activity),
                                "overlay" to Settings.canDrawOverlays(activity),
                                "battery" to pm.isIgnoringBatteryOptimizations(activity.packageName),
                                "notifications" to areNotificationsEnabled(activity),
                                "notificationListener" to isNotificationListenerEnabled(activity),
                                "defaultLauncher" to isDefaultLauncher(activity),
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ─── Apertura delle pagine di sistema ────────────────────────────────
    //
    // Regola comune a tutte: il PRIMO intent della cascata è sempre quello
    // che porta l'utente direttamente sull'interruttore di Koru; i successivi
    // degradano verso la lista generica e infine verso la root di Settings.
    // La cascata non è cosmetica: su vari OEM (OnePlus/Oppo/ColorOS/MIUI) gli
    // intent più specifici non sono risolvibili e `startActivity` solleva
    // ActivityNotFoundException che, se non catturata, termina il processo
    // Flutter.

    /**
     * Prova gli [intents] in ordine e lancia il primo che il sistema riesce a
     * risolvere. Ritorna `true` se una Activity è partita.
     *
     * `FLAG_ACTIVITY_NEW_TASK` su tutti: alcune di queste chiamate arrivano
     * mentre Koru non è l'Activity in cima (es. dall'overlay nativo).
     */
    private fun startFirstResolvable(activity: Activity, vararg intents: Intent): Boolean {
        for (intent in intents) {
            try {
                activity.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (_: Exception) {
                // intent non risolvibile su questo device → prova il successivo
            }
        }
        return false
    }

    /// Aggiunge gli extra AOSP che fanno aprire la lista di Settings già
    /// posizionata sulla riga [key] (package name o ComponentName appiattito).
    private fun highlightingRow(intent: Intent, key: String): Intent {
        val args = Bundle().apply { putString(EXTRA_FRAGMENT_ARG_KEY, key) }
        return intent
            .putExtra(EXTRA_FRAGMENT_ARG_KEY, key)
            .putExtra(EXTRA_SHOW_FRAGMENT_ARGS, args)
    }

    /**
     * Pagina di dettaglio del servizio di accessibilità di Koru.
     *
     * Da API 34 esiste l'intent ufficiale per il singolo servizio; prima di
     * allora l'unico appiglio è la lista generale + gli extra di highlight,
     * che quantomeno la aprono scrollata sulla riga di Koru.
     */
    private fun openAccessibilitySettings(activity: Activity) {
        val component =
            ComponentName(activity.packageName, ACCESSIBILITY_COMPONENT).flattenToString()
        val intents = mutableListOf<Intent>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            intents += Intent(ACTION_ACCESSIBILITY_DETAILS_SETTINGS)
                .putExtra(EXTRA_COMPONENT_NAME, component)
        }
        intents += highlightingRow(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS), component)
        intents += Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        intents += Intent(Settings.ACTION_SETTINGS)
        startFirstResolvable(activity, *intents.toTypedArray())
    }

    /**
     * Pagina "Accesso ai dati di utilizzo" di Koru. Non esiste un intent
     * ufficiale per-app: la Uri `package:` è però onorata dalla Settings AOSP
     * (e dalla maggior parte degli OEM) e apre direttamente l'interruttore.
     */
    private fun openUsageStatsSettings(activity: Activity) {
        val pkg = activity.packageName
        startFirstResolvable(
            activity,
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS, Uri.parse("package:$pkg")),
            highlightingRow(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS), pkg),
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS),
            Intent(Settings.ACTION_SETTINGS),
        )
    }

    private fun openOverlaySettings(activity: Activity) {
        val pkg = activity.packageName
        startFirstResolvable(
            activity,
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$pkg")),
            highlightingRow(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION), pkg),
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION),
            Intent(Settings.ACTION_SETTINGS),
        )
    }

    /**
     * `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` è il dialog di sistema che
     * concede l'esenzione con un tap; se l'OEM lo ha rimosso si ripiega sulla
     * lista "Ottimizzazione batteria" e infine sulla pagina dell'app.
     */
    private fun openBatteryOptimizationSettings(activity: Activity) {
        val pkg = activity.packageName
        startFirstResolvable(
            activity,
            Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$pkg"),
            ),
            highlightingRow(
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
                pkg,
            ),
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            appDetailsIntent(activity),
            Intent(Settings.ACTION_SETTINGS),
        )
    }

    private fun openNotificationListenerSettings(activity: Activity) {
        val component = ComponentName(
            activity.packageName,
            NOTIFICATION_LISTENER_COMPONENT,
        ).flattenToString()
        val intents = mutableListOf<Intent>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            intents += Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                .putExtra(
                    Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                    component,
                )
        }
        intents += highlightingRow(
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS),
            component,
        )
        intents += Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        intents += Intent(Settings.ACTION_SETTINGS)
        startFirstResolvable(activity, *intents.toTypedArray())
    }

    /// Pagina "Notifiche" dell'app: unica strada quando POST_NOTIFICATIONS è
    /// stata negata in modo permanente o quando l'utente ha spento le
    /// notifiche a mano (< API 33 non esiste alcun dialog runtime).
    private fun openAppNotificationSettings(activity: Activity) {
        startFirstResolvable(
            activity,
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName),
            appDetailsIntent(activity),
            Intent(Settings.ACTION_SETTINGS),
        )
    }

    private fun openDefaultLauncherSettings(activity: Activity) {
        startFirstResolvable(
            activity,
            Intent(Settings.ACTION_HOME_SETTINGS),
            Intent(Settings.ACTION_SETTINGS),
        )
    }

    private fun appDetailsIntent(activity: Activity): Intent =
        Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:${activity.packageName}"),
        )

    // ─── POST_NOTIFICATIONS ──────────────────────────────────────────────

    /**
     * Richiede il permesso di postare notifiche e risolve [result] con lo
     * stato finale. Tre strade, in ordine:
     *
     * 1. notifiche già attive → `true` senza toccare nulla;
     * 2. API 33+ e permesso mai negato in modo permanente → dialog runtime,
     *    la risposta arriva in [onRequestPermissionsResult];
     * 3. tutto il resto (API < 33, permesso già concesso ma notifiche spente
     *    a mano, dialog non lanciabile) → apre la pagina Notifiche dell'app,
     *    perché nessun dialog comparirebbe comunque.
     */
    private fun requestNotificationPermission(activity: Activity, result: MethodChannel.Result) {
        if (areNotificationsEnabled(activity)) {
            result.success(true)
            return
        }
        val canPrompt = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            activity.checkSelfPermission(PERMISSION_POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        if (!canPrompt) {
            openAppNotificationSettings(activity)
            result.success(false)
            return
        }
        // Un dialog già in volo (doppio tap): chiudi il Result precedente —
        // un MethodChannel.Result mai risolto lascia appesa la Future Dart.
        pendingNotificationResult?.success(false)
        pendingNotificationResult = result
        try {
            activity.requestPermissions(
                arrayOf(PERMISSION_POST_NOTIFICATIONS),
                REQ_POST_NOTIFICATIONS,
            )
        } catch (_: Exception) {
            pendingNotificationResult = null
            openAppNotificationSettings(activity)
            result.success(false)
        }
    }

    /**
     * Inoltrato da [com.dev.koru.MainActivity.onRequestPermissionsResult].
     * Ritorna `true` se [requestCode] apparteneva a questo channel.
     *
     * Al secondo "Non consentire" il sistema smette di mostrare il dialog
     * (`shouldShowRequestPermissionRationale` diventa false): da lì in poi
     * l'unica strada è la pagina di sistema, quindi la apriamo noi invece di
     * lasciare un tap che non produce nulla.
     */
    fun onRequestPermissionsResult(
        activity: Activity,
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQ_POST_NOTIFICATIONS) return false
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        val pending = pendingNotificationResult
        pendingNotificationResult = null
        if (!granted &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            !activity.shouldShowRequestPermissionRationale(PERMISSION_POST_NOTIFICATIONS)
        ) {
            openAppNotificationSettings(activity)
        }
        pending?.success(granted)
        return true
    }

    /// `areNotificationsEnabled` copre sia POST_NOTIFICATIONS (API 33+) sia lo
    /// spegnimento manuale delle notifiche dell'app — che è ciò che conta per
    /// il foreground service e gli alert dello strict mode.
    private fun areNotificationsEnabled(context: Context): Boolean = try {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.areNotificationsEnabled()
    } catch (_: Exception) {
        false
    }

    /**
     * Override delle gesture di sistema sul launcher (richiesto SOLO mentre
     * [com.dev.koru.MainActivity] mostra la LauncherHomeScreen; il lato Dart la
     * attiva on-mount e la rimuove on-dispose).
     *
     * Quando i telefoni hanno la navigazione a gesture attiva, il sistema
     * intercetta gli swipe dai bordi (sinistro/destro = indietro) prima che
     * arrivino all'app, rendendo inutilizzabili gli swipe personalizzati del
     * launcher. [android.view.View.setSystemGestureExclusionRects] dichiara le
     * zone in cui è l'app a gestire le gesture.
     *
     * Limiti di Android (non aggirabili da un'app):
     * - back gesture (bordi sx/dx): l'esclusione è limitata a 200dp per bordo
     *   (il sistema tiene i 200dp più in basso);
     * - home gesture (dal basso): la striscia mandatory è riservata e NON
     *   escludibile — lo swipe-su funziona solo se parte sopra la pillola.
     *
     * API 29+ (Q): no-op su versioni precedenti (lì la nav a 3 tasti non
     * confligge con gli swipe). Rect impostati via [View.post] perché servono
     * width/height dopo il layout pass.
     */
    private fun setLauncherGestureExclusion(activity: Activity, enabled: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val root = activity.window?.decorView ?: return
        root.post {
            val w = root.width
            val h = root.height
            root.systemGestureExclusionRects = if (enabled && w > 0 && h > 0) {
                listOf(Rect(0, 0, w, h))
            } else {
                emptyList()
            }
        }
    }

    private fun isAccessibilityEnabled(context: Context): Boolean {
        val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        return am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_GENERIC)
            .any { it.resolveInfo.serviceInfo.packageName == context.packageName }
    }

    /// `internal` (era private) per essere riusata da
    /// [com.dev.koru.widget.UsageWidgetDataSource]: PACKAGE_USAGE_STATS è una
    /// appops permission, quindi senza concessione `queryEvents` NON lancia —
    /// ritorna una lista vuota. Il widget deve poter distinguere "permesso
    /// mancante" da "non hai usato niente oggi", e l'unico modo è questo check.
    internal fun hasUsageStats(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        // `unsafeCheckOpNoThrow` esiste solo da API 29 (Q) mentre il minSdk è
        // 28: senza questa guardia, su Android 9 la chiamata solleva
        // NoSuchMethodError — un Error, non un'Exception, quindi sfugge alla
        // maggior parte dei try/catch e abbatte il processo. `checkOpNoThrow`
        // è l'API equivalente pre-29 (deprecata da 29, non rimossa).
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isNotificationListenerEnabled(context: Context): Boolean {
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        return enabled.split(":")
            .any { it.startsWith(context.packageName + "/") }
    }

    private fun isDefaultLauncher(context: Context): Boolean {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
        }
        val resolve = context.packageManager.resolveActivity(intent, 0)
        return resolve?.activityInfo?.packageName == context.packageName
    }
}
