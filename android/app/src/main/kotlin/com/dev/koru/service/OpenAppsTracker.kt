package com.dev.koru.service

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.view.accessibility.AccessibilityNodeInfo
import com.dev.koru.diagnostics.BlackBox
import java.util.ArrayDeque
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
        labelToPkg = null
        if (removed) tracked.remove(pkg)
    }

    // ─── Sync con le card REALI della schermata recents ──────────────────────
    //
    // Lo swipe-dismiss di una SINGOLA scheda nelle recents non genera alcun
    // evento osservabile (né a11y né UsageStats) → il set derivato dalla sola
    // sweep sovra-conta ("dice 1 app ma in background non c'è niente"). La
    // sola ground-truth accessibile è l'albero accessibility della schermata
    // recents MENTRE è aperta: a sessione legittima [LauncherRecentsGate]
    // chiama [syncFromRecents] (scansione iniziale + content-changed
    // throttlati) e il set viene RIMPIAZZATO con le card riconosciute.
    //
    // Limite documentato: con molte schede la RecyclerView dell'overview può
    // virtualizzare le card fuori schermo → possibile under-count dopo il
    // sync; le app tornano nel set appena usate (sweep/noteForeground).
    // Direzione di errore scelta apposta: meglio un conteggio momentaneamente
    // basso che un "1 fantasma" permanente.

    /// Label (lowercase) → package delle app launchable. Costruita off-main
    /// ([prewarmLabelMap], lanciata all'apertura di una sessione recents),
    /// invalidata sui package events. Serve a tradurre le contentDescription
    /// delle card (= label dell'app su quickstep) in package name.
    @Volatile private var labelToPkg: Map<String, String>? = null
    @Volatile private var labelMapBuilding = false

    /// Sotto questa soglia di nodi visitati un albero senza card NON è
    /// considerato prova di "recents vuote". Bassa di proposito: il guard sul
    /// root garantisce già che stiamo leggendo la finestra recents, e
    /// l'overview VUOTO è genuinamente un albero piccolo (scaffolding +
    /// testo "Nessun elemento recente") — una soglia alta impediva di
    /// leggere proprio lo zero che il sync esiste per catturare.
    internal const val MIN_NODES_FOR_EMPTY_TRUTH = 4

    /// Cap di sicurezza sul BFS dell'albero recents.
    private const val MAX_SCAN_NODES = 500

    fun prewarmLabelMap(context: Context) {
        if (labelToPkg != null || labelMapBuilding) return
        labelMapBuilding = true
        Thread {
            try {
                val pm = context.packageManager
                val self = context.packageName
                val m = HashMap<String, String>()
                val main = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                @Suppress("DEPRECATION")
                for (ri in pm.queryIntentActivities(main, 0)) {
                    val pkg = ri.activityInfo?.packageName ?: continue
                    if (pkg == self) continue
                    val label = ri.loadLabel(pm)?.toString()?.trim()?.lowercase() ?: continue
                    if (label.isNotEmpty()) m[label] = pkg
                }
                labelToPkg = m
            } catch (_: Exception) {
            } finally {
                labelMapBuilding = false
            }
        }.start()
    }

    /// Scansiona l'albero della schermata recents e riallinea il set. Da
    /// chiamare SOLO a sessione recents legittima (gate). Main thread (stessa
    /// classe di costo dei detector in-app esistenti; cap [MAX_SCAN_NODES]).
    fun syncFromRecents(service: KoruAccessibilityService) {
        val map = labelToPkg
        if (map == null) {
            // Mappa non pronta: avviala e riprova al prossimo content-change.
            prewarmLabelMap(service.applicationContext)
            return
        }
        service.withRootInActiveWindow { root ->
            if (root == null) return@withRootInActiveWindow
            // GUARD: la finestra ATTIVA deve essere davvero l'host recents.
            // Lo scan può partire durante l'animazione di apertura/chiusura
            // (o dopo l'auto-exit delle recents vuote): in quel momento il
            // root è l'app precedente o il launcher Koru — scansionare QUEL
            // albero produce falsi "vuoto" (osservato on-device: "0 schede"
            // con Chrome appena aperto) o falsi match sulle label dei
            // preferiti del launcher stesso.
            val rootPkg = root.packageName?.toString()
            if (rootPkg == null || rootPkg == service.packageName ||
                !RecentsDetector.isPlausibleRecentsHostPackage(
                    rootPkg, KoruAccessibilityService.SKIP_PACKAGES,
                )
            ) {
                return@withRootInActiveWindow
            }
            val matched = HashSet<String>()
            var sawClearAll = false
            var visited = 0
            val queue = ArrayDeque<AccessibilityNodeInfo>()
            queue.add(root)
            while (queue.isNotEmpty() && visited < MAX_SCAN_NODES) {
                val node = queue.poll() ?: continue
                visited++
                try {
                    val desc = node.contentDescription?.toString()
                    if (!desc.isNullOrBlank()) {
                        matchCardDescription(desc, map)?.let { matched.add(it) }
                    }
                    val viewId = try {
                        node.viewIdResourceName
                    } catch (_: Exception) {
                        null
                    }
                    if (!sawClearAll &&
                        RecentsDetector.isClearAllNode(viewId, desc ?: node.text)
                    ) {
                        sawClearAll = true
                    }
                    for (i in 0 until node.childCount) {
                        node.getChild(i)?.let { queue.add(it) }
                    }
                } finally {
                    // Il root lo ricicla withRootInActiveWindow; i figli sono
                    // caller-owned sotto API 33.
                    if (node !== root && Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                        @Suppress("DEPRECATION")
                        try {
                            node.recycle()
                        } catch (_: Throwable) {
                        }
                    }
                }
            }
            applyRecentsScan(service.applicationContext, matched, sawClearAll, visited, rootPkg)
        }
    }

    /// Traduce la contentDescription di una card in package: match esatto
    /// sulla label, oppure prefisso "label, ..." (alcune build accodano stato
    /// o timestamp alla description della TaskView).
    internal fun matchCardDescription(desc: String, labelMap: Map<String, String>): String? {
        val d = desc.trim().lowercase()
        labelMap[d]?.let { return it }
        val prefix = d.substringBefore(',').trim()
        if (prefix != d) labelMap[prefix]?.let { return it }
        return null
    }

    /// Regole di applicazione PURE (testabili): ritorna il nuovo set, o null
    /// per no-op. Zero card riconosciute è "verità di vuoto" SOLO se l'albero
    /// era sostanzioso E manca il bottone clear-all (quickstep lo nasconde a
    /// recents vuote): zero match con clear-all presente = card esistenti ma
    /// non mappate (label sconosciute) → non toccare il conteggio.
    internal fun computeRecentsSync(
        current: Set<String>,
        matched: Set<String>,
        sawClearAll: Boolean,
        visitedNodes: Int,
    ): Set<String>? {
        if (matched.isEmpty()) {
            val emptyIsTruth = !sawClearAll && visitedNodes >= MIN_NODES_FOR_EMPTY_TRUTH
            return if (emptyIsTruth && current.isNotEmpty()) emptySet() else null
        }
        if (current.size == matched.size && current.containsAll(matched)) return null
        return matched
    }

    @Synchronized
    private fun applyRecentsScan(
        context: Context,
        matchedRaw: Set<String>,
        sawClearAll: Boolean,
        visitedNodes: Int,
        rootPkg: String,
    ) {
        val self = context.packageName
        val matched = matchedRaw.filterTo(HashSet()) {
            shouldTrack(it, self, KoruAccessibilityService.SKIP_PACKAGES, isLaunchable = true)
        }
        val next = computeRecentsSync(tracked.toSet(), matched, sawClearAll, visitedNodes)
            ?: return
        tracked.clear()
        tracked.addAll(next)
        BlackBox.log(
            "RECENTS",
            "sync da recents (root=$rootPkg, nodi=$visitedNodes): ${next.size} schede" +
                if (next.isEmpty()) " (vuote)" else " [${next.joinToString()}]",
        )
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
