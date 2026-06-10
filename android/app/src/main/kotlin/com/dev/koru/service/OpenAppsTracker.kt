package com.dev.koru.service

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.SystemClock
import com.dev.koru.diagnostics.BlackBox
import java.util.concurrent.ConcurrentHashMap

/// Conteggio approssimato delle "schede aperte in background" mostrato
/// dall'icona top-left del launcher. Android non espone la vera lista recents
/// alle app di terze parti (getRecentTasks è ristretta da API 21), quindi la
/// semantica — concordata col design — è: **app portate in foreground dal
/// boot** (o dall'ultimo reset), escluse quelle non-launchable e i package di
/// sistema/launcher.
///
/// FONTE: UsageStatsManager.queryEvents (ACTIVITY_RESUMED), NON gli
/// AccessibilityEvent: il watched-set dinamico
/// ([KoruAccessibilityService.applyDynamicPackageFilter]) filtra gli eventi
/// alle sole app con profilo/limite, quindi un tracker accessibility-fed
/// sotto-conterebbe sistematicamente. Gli eventi a11y alimentano il set solo
/// opportunisticamente via [noteForeground] (gratis quando arrivano).
///
/// RESTART-PROOF BY CONSTRUCTION: il set in-memory si perde col processo, ma
/// la prima sweep dopo il riavvio ri-deriva tutto dal boot (UsageStats
/// conserva gli eventi per giorni). L'unico stato persistito è l'ancora del
/// reset ([resetAll], SharedPreferences): il `max()` col bootTime in
/// [sweepWindowStartMs] rende un'ancora di un boot precedente innocua.
///
/// Limiti documentati (approssimazione accettata): app force-stoppate dal
/// sistema o swipe-ate via singolarmente dalle recents restano contate fino
/// al prossimo reset (clear-all rilevato o long-press sull'icona); UsageStats
/// scarta gli eventi dopo ~1 settimana, quindi su uptime molto lunghi le app
/// aperte solo molto tempo fa escono dal conteggio da sole.
object OpenAppsTracker {
    private const val PREFS = "koru_open_apps_tracker"
    private const val KEY_RESET_WALL_MS = "reset_wall_ms"

    /// Overlap della finestra incrementale: ri-leggiamo gli ultimi 2s della
    /// sweep precedente per non perdere eventi a cavallo (i timestamp di
    /// UsageStats e i nostri non sono sincronizzati al ms).
    internal const val SWEEP_OVERLAP_MS = 2_000L

    /// Throttle: due sweep nello stesso burst (es. resume launcher + pull del
    /// provider) non hanno senso — la seconda non vedrebbe eventi nuovi.
    private const val MIN_SWEEP_INTERVAL_MS = 2_000L

    private val tracked: MutableSet<String> = ConcurrentHashMap.newKeySet()
    private val launchableCache = ConcurrentHashMap<String, Boolean>()

    @Volatile private var lastSweepEndWallMs = 0L
    @Volatile private var lastSweepUptimeMs = 0L

    /// -1 = ancora mai letto dalle prefs (lazy load alla prima sweep).
    @Volatile private var resetWallMs = -1L

    /// Conteggio corrente, preceduto da una sweep incrementale (throttled).
    /// Chiamare OFF-MAIN (la sweep fa una query UsageStats): il channel
    /// handler usa il pattern Thread + runOnUiThread.
    fun count(context: Context): Int {
        refresh(context)
        return tracked.size
    }

    @Synchronized
    fun refresh(context: Context) {
        val nowUp = SystemClock.uptimeMillis()
        if (lastSweepEndWallMs > 0 && nowUp - lastSweepUptimeMs < MIN_SWEEP_INTERVAL_MS) return
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return
        val now = System.currentTimeMillis()
        val bootWallMs = now - SystemClock.elapsedRealtime()
        var start = sweepWindowStartMs(
            bootWallMs = bootWallMs,
            resetWallMs = readResetAnchor(context),
            lastSweepEndWallMs = lastSweepEndWallMs,
            overlapMs = SWEEP_OVERLAP_MS,
        )
        if (start > now) {
            // Orologio spostato all'indietro (manuale/NITZ) dopo una sweep o
            // un reset: senza clamp la finestra resterebbe nel futuro e il
            // contatore congelato finché il wall clock non la raggiunge.
            // Ri-ancoriamo a `now` (costo: una sola ri-scansione overlap) e
            // correggiamo l'ancora persistita se anch'essa nel futuro.
            start = now - SWEEP_OVERLAP_MS
            if (resetWallMs > now) {
                resetWallMs = now
                try {
                    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                        .edit()
                        .putLong(KEY_RESET_WALL_MS, now)
                        .apply()
                } catch (_: Exception) {
                }
            }
        }
        if (start < now) {
            val events = usm.queryEvents(start, now) ?: return
            val event = UsageEvents.Event()
            val self = context.packageName
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType != UsageEvents.Event.ACTIVITY_RESUMED) continue
                val pkg = event.packageName ?: continue
                if (tracked.contains(pkg)) continue
                if (shouldTrack(
                        pkg = pkg,
                        selfPackage = self,
                        skipPackages = KoruAccessibilityService.SKIP_PACKAGES,
                        isLaunchable = isLaunchable(context, pkg),
                    )
                ) {
                    tracked.add(pkg)
                }
            }
        }
        // Prune: le disinstallate (launch intent sparito) escono dal set al
        // read — query PM fresca, NON la cache (che esiste per rendere
        // economico il hot path di noteForeground, non per il prune).
        tracked.removeAll { pkg ->
            val launchable = queryLaunchable(context, pkg)
            launchableCache[pkg] = launchable
            !launchable
        }
        lastSweepEndWallMs = now
        lastSweepUptimeMs = nowUp
    }

    /// Add opportunistico dal hot path accessibility (TYPE_WINDOW_STATE_CHANGED
    /// di un'app reale): gratis quando l'evento arriva, ma NON è la fonte di
    /// verità (vedi doc dell'object). Costo: un lookup nel set + (solo alla
    /// prima vista di un pkg) una query PM cache-ata.
    fun noteForeground(context: Context, pkg: String) {
        if (tracked.contains(pkg)) return
        if (shouldTrack(
                pkg = pkg,
                selfPackage = context.packageName,
                skipPackages = KoruAccessibilityService.SKIP_PACKAGES,
                isLaunchable = isLaunchable(context, pkg),
            )
        ) {
            tracked.add(pkg)
        }
    }

    /// Hook dal receiver dei package events: prune immediato su uninstall
    /// (best-effort — il receiver vive solo con l'Activity visibile; il prune
    /// autoritativo è quello in [refresh]) e invalidazione cache su qualsiasi
    /// cambiamento del package.
    fun onPackageChanged(pkg: String, removed: Boolean) {
        launchableCache.remove(pkg)
        if (removed) tracked.remove(pkg)
    }

    /// Azzera il conteggio e persiste l'ancora: usato dal long-press
    /// sull'icona del launcher e dal rilevamento best-effort di "Cancella
    /// tutto" nelle recents ([LauncherRecentsGate]).
    ///
    /// @Synchronized: serializza con [refresh] (che gira sul thread di
    /// background del channel handler). Senza, un clear() a metà di una sweep
    /// in volo si fa ri-aggiungere package pre-reset dagli add successivi
    /// dell'iterazione — e la finestra incrementale non li rivaluta mai →
    /// conteggio non-zero permanente dopo il reset. Il blocco è accettabile:
    /// azione user-initiated, durata sweep limitata.
    @Synchronized
    fun resetAll(context: Context) {
        val now = System.currentTimeMillis()
        tracked.clear()
        resetWallMs = now
        lastSweepEndWallMs = now
        try {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putLong(KEY_RESET_WALL_MS, now)
                .apply()
        } catch (e: Exception) {
            BlackBox.log("RECENTS", "reset anchor non persistita: ${e.message}")
        }
        BlackBox.log("RECENTS", "tracker reset → count 0")
    }

    private fun readResetAnchor(context: Context): Long {
        var v = resetWallMs
        if (v < 0) {
            v = try {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .getLong(KEY_RESET_WALL_MS, 0L)
            } catch (_: Exception) {
                0L
            }
            resetWallMs = v
        }
        return v
    }

    private fun isLaunchable(context: Context, pkg: String): Boolean =
        launchableCache.getOrPut(pkg) { queryLaunchable(context, pkg) }

    private fun queryLaunchable(context: Context, pkg: String): Boolean = try {
        context.packageManager.getLaunchIntentForPackage(pkg) != null
    } catch (_: Exception) {
        false
    }

    // ─── Logica PURA (unit-testabile senza Robolectric) ──────────────────────

    /// Inizio della finestra di sweep: mai prima del boot corrente (così
    /// un'ancora di reset di un boot precedente è innocua), mai prima del
    /// reset, e incrementale rispetto all'ultima sweep (con overlap anti-gap).
    internal fun sweepWindowStartMs(
        bootWallMs: Long,
        resetWallMs: Long,
        lastSweepEndWallMs: Long,
        overlapMs: Long,
    ): Long = maxOf(
        bootWallMs,
        resetWallMs,
        if (lastSweepEndWallMs > 0) lastSweepEndWallMs - overlapMs else 0L,
    )

    /// Esclusioni del conteggio: self (Koru), framework/systemui/launcher
    /// (skip-set del service — copre anche l'host delle recents) e package
    /// senza launch intent (IME, permission dialogs, resolver/share sheet;
    /// fa anche sparire le disinstallate al read). Settings di sistema CONTA
    /// come scheda (è un task visibile nelle recents).
    internal fun shouldTrack(
        pkg: String,
        selfPackage: String,
        skipPackages: Set<String>,
        isLaunchable: Boolean,
    ): Boolean {
        if (pkg.isEmpty() || pkg == selfPackage) return false
        if (skipPackages.contains(pkg)) return false
        return isLaunchable
    }

    // ─── Solo per i test: reset dello stato in-memory ────────────────────────

    internal fun debugResetInMemoryState() {
        tracked.clear()
        launchableCache.clear()
        lastSweepEndWallMs = 0L
        lastSweepUptimeMs = 0L
        resetWallMs = -1L
    }
}
