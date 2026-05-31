package com.dev.koru.channels.blocking

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Concern: inventario delle app installate per il drawer/launcher e per i
 * provider che incrociano la lista (limiti, filtro notifiche). Estratto da
 * `BlockingMethodChannel` (ARCH-09) insieme a tutti i suoi helper privati;
 * comportamento e wire-contract invariati.
 *
 * `getInstalledApps` resta offloadato su un [Thread] di background: scansiona
 * tutti i package, decodifica l'icona da APK e fa un compress PNG per ciascuno
 * (1-3s su set realistici) — sul Platform main thread freezerebbe la UI Flutter.
 */
internal object AppInventoryCallHandler : BlockingCallHandler {

    override val methods = setOf(
        "getInstalledApps",
        "getInstalledPackageNames",
        "getLauncherPackageNames",
        "getAppIcon",
    )

    override fun handle(call: MethodCall, result: MethodChannel.Result, activity: Activity) {
        when (call.method) {
            "getInstalledApps" -> {
                // Offload su background thread: `getInstalledApps`
                // scansiona TUTTI i package, chiama
                // `getApplicationIcon` (decode drawable da APK) e fa
                // un compress PNG per ciascuno. Su set realistici
                // (60-150 app) può prendere 1-3s e bloccare il
                // Platform main thread, freezando la UI Flutter
                // (che attende il method channel result). Eseguiamo
                // tutto su Thread() e torniamo alla UI thread solo
                // per `result.success`/`result.error`.
                Thread {
                    try {
                        val data = getInstalledApps(activity)
                        activity.runOnUiThread { result.success(data) }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error(
                                "INSTALLED_APPS_ERROR",
                                e.message,
                                null,
                            )
                        }
                    }
                }.start()
            }
            "getInstalledPackageNames" -> {
                // PERF: stesso offload di `getInstalledApps`. Anche senza decode
                // delle icone, fa `getInstalledApplications(0)` +
                // `queryIntentActivities` + filter + sort: una scansione via
                // binder verso system_server. È invocato dal lifecycle observer
                // Dart a ogni resume (con Koru launcher = molto spesso): sul
                // Platform main thread aggiunge latenza di input al rientro.
                // Eseguiamo su Thread() e torniamo alla UI thread solo per il
                // result.
                Thread {
                    try {
                        val names = getInstalledPackageNames(activity)
                        activity.runOnUiThread { result.success(names) }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error(
                                "INSTALLED_PACKAGE_NAMES_ERROR",
                                e.message,
                                null,
                            )
                        }
                    }
                }.start()
            }
            "getLauncherPackageNames" -> {
                // Set di package che dichiarano un'activity HOME
                // (sono altri launcher installati: Nova, Pixel
                // Launcher, ecc.). Esposto separatamente da
                // `getInstalledApps` per non dover toccare lo schema
                // di `InstalledAppInfo` lato Dart; il provider Dart
                // fa il merge.
                result.success(
                    resolveLauncherPackages(activity.packageManager).toList()
                )
            }
            "getAppIcon" -> {
                val pkg = call.argument<String>("packageName")
                if (pkg == null) {
                    result.error("ARG_ERROR", "packageName required", null)
                    return
                }
                // Decode su background thread: getApplicationIcon decodifica il
                // drawable dall'APK + compress PNG (~ms per icona). Off dal
                // Platform main thread; null se l'app non ha icona / fallisce.
                Thread {
                    val bytes = try {
                        getAppIcon(activity, pkg)
                    } catch (e: Exception) {
                        null
                    }
                    activity.runOnUiThread { result.success(bytes) }
                }.start()
            }
        }
    }

    private fun getInstalledApps(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        val launcherPkgs = resolveLauncherPackages(pm)
        val launchablePkgs = resolveLaunchablePackages(pm)
        return pm.getInstalledApplications(PackageManager.GET_META_DATA)
            // Solo app con un'activity lanciabile (MAIN + CATEGORY_LAUNCHER),
            // come ogni launcher stock. Il vecchio criterio
            // `FLAG_SYSTEM == 0 || hasLaunchIntent` lasciava passare i
            // componenti Google distribuiti via Play Store (Android System
            // SafetyCore, Key Verifier, ...) e le tastiere/IME: NON sono di
            // sistema (FLAG_SYSTEM == 0) ma non hanno front-door → comparivano
            // nel drawer pur non essendo apribili (tap = niente). Gating per
            // membership nel set launchable li esclude tutti, senza denylist
            // hardcoded da mantenere quando Google ne aggiunge altri.
            .filter { launchablePkgs.contains(it.packageName) }
            .map { app ->
                // PERF: niente icona qui. Decodificare + comprimere un PNG per
                // OGNI app (1-3s al cold start su set realistici) era il costo
                // dominante dell'inventario. Le icone si caricano on-demand per
                // package via `getAppIcon`, solo dove servono.
                mapOf(
                    "packageName" to app.packageName,
                    "label" to (pm.getApplicationLabel(app)?.toString() ?: app.packageName),
                    "isLauncher" to launcherPkgs.contains(app.packageName),
                )
            }
            .sortedBy { (it["label"] as String).lowercase() }
    }

    /// Set di package che dichiarano almeno un'activity con
    /// CATEGORY_HOME (cioè sono launcher). Calcolato una volta per
    /// chiamata a `getInstalledApps` e poi usato come lookup O(1) per
    /// taggare il flag `isLauncher` su ciascuna app — il Dart-side
    /// filtra il drawer per nascondere altri launcher (Nova, Pixel
    /// Launcher, ecc.) che altrimenti creavano confusione.
    private fun resolveLauncherPackages(pm: PackageManager): Set<String> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        return try {
            pm.queryIntentActivities(intent, 0)
                .mapNotNull { it.activityInfo?.packageName }
                .toSet()
        } catch (_: Exception) {
            emptySet()
        }
    }

    /// Set di package che dichiarano almeno un'activity con
    /// CATEGORY_LAUNCHER, cioè sono apribili dal drawer (hanno un'icona
    /// "front-door"). È il criterio di visibilità del drawer Koru: tutto
    /// ciò che non è in questo set — componenti Play come SafetyCore /
    /// Key Verifier, IME/tastiere, servizi di background — non è apribile
    /// e va nascosto. Speculare a [resolveLauncherPackages] ma con
    /// CATEGORY_LAUNCHER al posto di CATEGORY_HOME.
    private fun resolveLaunchablePackages(pm: PackageManager): Set<String> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return try {
            pm.queryIntentActivities(intent, 0)
                .mapNotNull { it.activityInfo?.packageName }
                .toSet()
        } catch (_: Exception) {
            emptySet()
        }
    }

    /// Variante "cheap" usata dal lifecycle observer Dart per il diff-based
    /// refresh: ritorna solo i package names launchable, senza label e
    /// senza icone, evitando il decode delle bitmap (operazione costosa
    /// che — se eseguita ad ogni resume — causa un freeze visibile della UI).
    private fun getInstalledPackageNames(context: Context): List<String> {
        val pm = context.packageManager
        // Stesso criterio di [getInstalledApps] — i due endpoint DEVONO
        // ritornare lo stesso set di package: sono fotografie consistenti
        // dello stesso PackageManager (TodayLimitsCard incrocia questa lista
        // col drawer per filtrare le entries fantasma di app disinstallate).
        // Una sola queryIntentActivities invece di N getLaunchIntentForPackage:
        // questo è il path "cheap" invocato a ogni resume.
        val launchablePkgs = resolveLaunchablePackages(pm)
        return pm.getInstalledApplications(0)
            .filter { launchablePkgs.contains(it.packageName) }
            .map { it.packageName }
            .sorted()
    }

    /// Icona PNG di una singola app, decodificata on-demand. Speculare al
    /// vecchio campo `icon` di [getInstalledApps], rimosso dall'inventario bulk
    /// per non pagare il decode di tutte le icone al cold start.
    private fun getAppIcon(context: Context, packageName: String): ByteArray? {
        return try {
            drawableToBytes(context.packageManager.getApplicationIcon(packageName))
        } catch (e: Exception) {
            null
        }
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
