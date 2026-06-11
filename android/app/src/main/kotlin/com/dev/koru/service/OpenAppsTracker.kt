package com.dev.koru.service

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.view.accessibility.AccessibilityNodeInfo
import com.dev.koru.channels.ServiceEventChannel
import com.dev.koru.diagnostics.BlackBox
import org.json.JSONObject
import java.util.ArrayDeque
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

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

    /// Dopo un reset (Cancella tutto / long-press) il sync con le card è MUTO
    /// per questa finestra: le scansioni del burst leggono le card ancora
    /// attaccate durante l'animazione di chiusura e le ri-aggiungerebbero
    /// (osservato on-device: clear-all → reset → scan a +300ms → di nuovo 1).
    private const val SYNC_MUTE_AFTER_RESET_MS = 2_000L

    /// Grazia post-reset per i RESUME FANTASMA: su OxygenOS il clear-all fa
    /// transitare le app appena chiuse per un vero ACTIVITY_RESUMED 1-2s DOPO
    /// il click (osservato via dumpsys usagestats: reset a 11:25:04.96,
    /// com.whatsapp RESUMED a 11:25:06 e 11:25:07) → la sweep successiva,
    /// la cui finestra parte proprio dal reset, le ri-aggiungeva e il badge
    /// tornava al valore vecchio. Entro questa finestra gli eventi dei SOLI
    /// package azzerati dal reset ([clearedAtReset]) vengono ignorati, sia
    /// dalla sweep sia da noteForeground: un'app diversa aperta subito dopo
    /// il reset resta contata normalmente.
    internal const val RESET_EVENT_GRACE_MS = 3_500L

    /// Il prune "fresco" (query PM per ogni pkg tracciato, bypass cache) gira
    /// al massimo a questo intervallo: farlo a OGNI sweep aggiungeva N binder
    /// call al pull del conteggio (lentezza percepita del badge). Tra un
    /// prune fresco e l'altro si usa la cache, che i package events
    /// invalidano comunque al volo quando il receiver è vivo.
    private const val PRUNE_FRESH_INTERVAL_MS = 60_000L

    @Volatile private var muteSyncUntilUptimeMs = 0L
    @Volatile private var lastFreshPruneUptimeMs = 0L

    /// Package azzerati dall'ultimo [resetAll] + fine della grazia anti
    /// resume-fantasma (wall per la sweep, uptime per noteForeground).
    @Volatile private var clearedAtReset: Set<String> = emptySet()
    @Volatile private var resetGraceEndWallMs = 0L
    @Volatile private var resetGraceEndUptimeMs = 0L

    /// Set IMMUTABILE swappato copy-on-write sotto [stateLock]: i reader
    /// (push, pull, fast-path di noteForeground) leggono il volatile senza
    /// lock e vedono sempre uno snapshot coerente — il vecchio pattern
    /// clear()+addAll() esponeva lo stato a metà replace (pull transitorio
    /// sotto-stimato, push col size sbagliato).
    @Volatile private var tracked: Set<String> = emptySet()

    /// Serializza TUTTI i writer del set e delle ancore. ReentrantLock
    /// esplicito (non @Synchronized) così [noteForeground] può fare tryLock:
    /// è il hot path a11y sul main thread e il lock può essere tenuto da una
    /// sweep UsageStats per decine di ms (prima sweep post-restart).
    private val stateLock = ReentrantLock()

    /// Seq monotono delle mutazioni del set: incluso nel push E nel pull,
    /// il Dart scarta i valori con seq più vecchio di quello già visto
    /// (race "pull stale sovrascrive push più fresco"). Riparte da 0 solo
    /// con la morte del processo — che uccide anche il Dart (stesso
    /// processo, nessun android:process) → confronto monotono safe.
    private val mutationSeq = AtomicLong(0)

    private val launchableCache = ConcurrentHashMap<String, Boolean>()

    @Volatile private var lastSweepEndWallMs = 0L
    @Volatile private var lastSweepUptimeMs = 0L

    /// Floor della finestra di sweep dopo un sync con le card reali: a
    /// differenza di [lastSweepEndWallMs] NON subisce l'overlap. Il replace
    /// del set È la verità a quell'istante — senza questo floor la sweep
    /// successiva (al resume del launcher) rilegge gli ACTIVITY_RESUMED
    /// precedenti al sync e "resuscita" una scheda appena swipe-ata via
    /// (count vecchio finché non si rientra/riesce dalle recents). Non
    /// persistito di proposito: dopo un process restart la sweep ri-deriva
    /// tutto dal boot by design.
    @Volatile private var recentsSyncFloorWallMs = 0L

    /// -1 = ancora mai letto dalle prefs (lazy load alla prima sweep).
    @Volatile private var resetWallMs = -1L

    /// Conteggio + seq per il pull, preceduti da una sweep incrementale
    /// (throttled) e letti ATOMICAMENTE sotto lock: un pull non deve poter
    /// accoppiare un count vecchio con un seq nuovo — il Dart lo accetterebbe
    /// e scarterebbe il push genuino successivo. Chiamare OFF-MAIN (la sweep
    /// fa una query UsageStats): il channel handler usa il pattern
    /// Thread + runOnUiThread.
    fun countWithSeq(context: Context): Pair<Int, Long> {
        refresh(context)
        return stateLock.withLock { tracked.size to mutationSeq.get() }
    }

    fun refresh(context: Context): Unit = stateLock.withLock {
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
            recentsSyncFloorWallMs = recentsSyncFloorWallMs,
        )
        if (start > now) {
            // Orologio spostato all'indietro (manuale/NITZ) dopo una sweep o
            // un reset: senza clamp la finestra resterebbe nel futuro e il
            // contatore congelato finché il wall clock non la raggiunge.
            // Ri-ancoriamo a `now` (costo: una sola ri-scansione overlap) e
            // correggiamo l'ancora persistita se anch'essa nel futuro.
            start = now - SWEEP_OVERLAP_MS
            if (recentsSyncFloorWallMs > now) recentsSyncFloorWallMs = now
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
        // Copy-on-write: la sweep lavora su una copia e pubblica lo swap
        // solo a fine lavoro — i reader non vedono mai stati intermedi.
        val next = HashSet(tracked)
        if (start < now) {
            val events = usm.queryEvents(start, now) ?: return
            val event = UsageEvents.Event()
            val self = context.packageName
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType != UsageEvents.Event.ACTIVITY_RESUMED) continue
                val pkg = event.packageName ?: continue
                if (next.contains(pkg)) continue
                if (isPostResetGhost(
                        pkg = pkg,
                        eventWallMs = event.timeStamp,
                        graceEndWallMs = resetGraceEndWallMs,
                        clearedAtReset = clearedAtReset,
                    )
                ) {
                    continue
                }
                if (shouldTrack(
                        pkg = pkg,
                        selfPackage = self,
                        skipPackages = KoruAccessibilityService.SKIP_PACKAGES,
                        isLaunchable = isLaunchable(context, pkg),
                    )
                ) {
                    next.add(pkg)
                }
            }
        }
        // Prune: le disinstallate (launch intent sparito) escono dal set al
        // read. Query PM fresca solo a intervalli (PRUNE_FRESH_INTERVAL_MS):
        // una binder call per pkg a ogni sweep rendeva lento il pull del
        // badge; tra un prune fresco e l'altro basta la cache.
        val freshPrune = nowUp - lastFreshPruneUptimeMs >= PRUNE_FRESH_INTERVAL_MS
        if (freshPrune) lastFreshPruneUptimeMs = nowUp
        next.removeAll { pkg ->
            val launchable = if (freshPrune) {
                val l = queryLaunchable(context, pkg)
                launchableCache[pkg] = l
                l
            } else {
                isLaunchable(context, pkg)
            }
            !launchable
        }
        lastSweepEndWallMs = now
        lastSweepUptimeMs = nowUp
        if (next != tracked) publishLocked(next)
    }

    /// Add opportunistico dal hot path accessibility (TYPE_WINDOW_STATE_CHANGED
    /// di un'app reale): gratis quando l'evento arriva, ma NON è la fonte di
    /// verità (vedi doc dell'object). Costo: un lookup nel set + (solo alla
    /// prima vista di un pkg) una query PM cache-ata.
    fun noteForeground(context: Context, pkg: String) {
        // Fast-path lock-free sul volatile: il caso comune (pkg già contato)
        // non paga nulla.
        if (tracked.contains(pkg)) return
        // Resume fantasma post clear-all (vedi RESET_EVENT_GRACE_MS): i
        // window event delle app appena azzerate non devono ri-contarle.
        if (SystemClock.uptimeMillis() < resetGraceEndUptimeMs &&
            clearedAtReset.contains(pkg)
        ) {
            return
        }
        if (!shouldTrack(
                pkg = pkg,
                selfPackage = context.packageName,
                skipPackages = KoruAccessibilityService.SKIP_PACKAGES,
                isLaunchable = isLaunchable(context, pkg),
            )
        ) {
            return
        }
        // tryLock e non lock: siamo sul main thread a11y e il lock può
        // essere tenuto da una sweep UsageStats per decine di ms. Perdere
        // l'add sotto contesa è nel contratto ("opportunistico, NON fonte
        // di verità"): la sweep in corso lo recupera lei stessa.
        if (!stateLock.tryLock()) return
        try {
            if (!tracked.contains(pkg)) publishLocked(tracked + pkg)
        } finally {
            stateLock.unlock()
        }
    }

    /// Hook dal receiver dei package events: prune immediato su uninstall
    /// (best-effort — il receiver vive solo con l'Activity visibile; il prune
    /// autoritativo è quello in [refresh]) e invalidazione cache su qualsiasi
    /// cambiamento del package.
    fun onPackageChanged(pkg: String, removed: Boolean) {
        launchableCache.remove(pkg)
        labelToPkg = null
        if (!removed) return
        stateLock.withLock {
            if (pkg in tracked) publishLocked(tracked - pkg)
        }
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

    /// Esito di [syncFromRecents] per il gate: gli SKIPPED non hanno letto
    /// l'albero recents (non consumano tentativi del burst né throttle);
    /// RETRY_SUGGESTED = scansione ambigua (zero card mappate ma clear-all
    /// presente) — un re-scan ravvicinato può disambiguare.
    internal enum class RecentsScanOutcome { SKIPPED_NO_MAP, SKIPPED_NOT_RECENTS, DONE, RETRY_SUGGESTED }

    /// Scansiona l'albero della schermata recents e riallinea il set. Da
    /// chiamare SOLO a sessione recents legittima (gate). Main thread (stessa
    /// classe di costo dei detector in-app esistenti; cap [MAX_SCAN_NODES]).
    internal fun syncFromRecents(service: KoruAccessibilityService): RecentsScanOutcome {
        val map = labelToPkg
        if (map == null) {
            // Mappa non pronta: avviala e riprova al prossimo content-change.
            prewarmLabelMap(service.applicationContext)
            return RecentsScanOutcome.SKIPPED_NO_MAP
        }
        var outcome = RecentsScanOutcome.SKIPPED_NOT_RECENTS
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
            outcome = applyRecentsScan(service.applicationContext, matched, sawClearAll, visited, rootPkg)
        }
        return outcome
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

    /// Esito PURO del confronto set/card (testabile).
    internal sealed interface RecentsSyncDecision {
        data class Apply(val next: Set<String>) : RecentsSyncDecision
        object NoOp : RecentsSyncDecision

        /// Zero card mappate ma clear-all presente con set non vuoto: o label
        /// sconosciute (no-op definitivo) o animazione di "Cancella tutto" in
        /// corso — le card spariscono dall'albero PRIMA del bottone, quindi
        /// in quel transitorio lo zero è reale ma vetato. Un re-scan
        /// ravvicinato distingue i due casi: a bottone sparito lo zero
        /// diventa leggibile, a card ricomparse resta no-op.
        object RetryLater : RecentsSyncDecision
    }

    /// Regole di applicazione PURE (testabili). Zero card riconosciute è
    /// "verità di vuoto" SOLO se l'albero era sostanzioso E manca il bottone
    /// clear-all (quickstep lo nasconde a recents vuote): zero match con
    /// clear-all presente = ambiguo → [RecentsSyncDecision.RetryLater].
    internal fun computeRecentsSync(
        current: Set<String>,
        matched: Set<String>,
        sawClearAll: Boolean,
        visitedNodes: Int,
    ): RecentsSyncDecision {
        if (matched.isEmpty()) {
            if (current.isEmpty()) return RecentsSyncDecision.NoOp
            if (sawClearAll) return RecentsSyncDecision.RetryLater
            return if (visitedNodes >= MIN_NODES_FOR_EMPTY_TRUTH) {
                RecentsSyncDecision.Apply(emptySet())
            } else {
                RecentsSyncDecision.NoOp
            }
        }
        if (current.size == matched.size && current.containsAll(matched)) {
            return RecentsSyncDecision.NoOp
        }
        return RecentsSyncDecision.Apply(matched)
    }

    private fun applyRecentsScan(
        context: Context,
        matchedRaw: Set<String>,
        sawClearAll: Boolean,
        visitedNodes: Int,
        rootPkg: String,
    ): RecentsScanOutcome = stateLock.withLock {
        // Post-reset (Cancella tutto / long-press): le card in animazione di
        // chiusura sono ancora nell'albero — applicare questa scansione le
        // ri-aggiungerebbe subito dopo l'azzeramento (osservato on-device).
        // DONE e non RETRY_SUGGESTED: dopo un resetAll il conteggio è già
        // zero, un retry sprecherebbe solo budget.
        if (SystemClock.uptimeMillis() < muteSyncUntilUptimeMs) return RecentsScanOutcome.DONE
        val self = context.packageName
        val matched = matchedRaw.filterTo(HashSet()) {
            shouldTrack(it, self, KoruAccessibilityService.SKIP_PACKAGES, isLaunchable = true)
        }
        return when (val decision = computeRecentsSync(tracked, matched, sawClearAll, visitedNodes)) {
            is RecentsSyncDecision.NoOp -> RecentsScanOutcome.DONE
            is RecentsSyncDecision.RetryLater -> RecentsScanOutcome.RETRY_SUGGESTED
            is RecentsSyncDecision.Apply -> {
                BlackBox.log(
                    "RECENTS",
                    "sync da recents (root=$rootPkg, nodi=$visitedNodes): ${decision.next.size} schede" +
                        if (decision.next.isEmpty()) " (vuote)" else " [${decision.next.joinToString()}]",
                )
                applyRecentsResult(decision.next, System.currentTimeMillis())
                RecentsScanOutcome.DONE
            }
        }
    }

    /// Replace del set + avanzamento delle ancore di sweep (anti-resurrezione:
    /// vedi [recentsSyncFloorWallMs]). Estratta da [applyRecentsScan] per
    /// essere testabile in JUnit puro — il wrapper Context-bound filtra e
    /// decide, qui solo la transizione di stato. ReentrantLock rientrante:
    /// la chiamata annidata dal wrapper è sicura.
    internal fun applyRecentsResult(next: Set<String>, nowWallMs: Long) {
        stateLock.withLock {
            lastSweepEndWallMs = nowWallMs
            recentsSyncFloorWallMs = nowWallMs
            publishLocked(next.toSet())
        }
    }

    /// Azzera il conteggio e persiste l'ancora: usato dal long-press
    /// sull'icona del launcher e dal rilevamento best-effort di "Cancella
    /// tutto" nelle recents ([LauncherRecentsGate]).
    ///
    /// [stateLock]: serializza con [refresh] (che gira sul thread di
    /// background del channel handler). Senza, un azzeramento a metà di una
    /// sweep in volo si fa ri-aggiungere package pre-reset dal publish
    /// successivo della sweep — e la finestra incrementale non li rivaluta
    /// mai → conteggio non-zero permanente dopo il reset. Chiamare OFF-MAIN
    /// (il lock può essere dietro una sweep UsageStats).
    fun resetAll(context: Context) {
        stateLock.withLock {
            val now = System.currentTimeMillis()
            val nowUp = SystemClock.uptimeMillis()
            resetWallMs = now
            lastSweepEndWallMs = now
            // Grazia anti resume-fantasma sui package appena azzerati (vedi
            // RESET_EVENT_GRACE_MS): snapshot del set PRIMA del clear.
            clearedAtReset = tracked
            resetGraceEndWallMs = now + RESET_EVENT_GRACE_MS
            resetGraceEndUptimeMs = nowUp + RESET_EVENT_GRACE_MS
            // Le card stanno ancora animando la chiusura: le scansioni del
            // burst nei prossimi istanti le rileggerebbero e ri-aggiungerebbero.
            muteSyncUntilUptimeMs = nowUp + SYNC_MUTE_AFTER_RESET_MS
            try {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .putLong(KEY_RESET_WALL_MS, now)
                    .apply()
            } catch (e: Exception) {
                BlackBox.log("RECENTS", "reset anchor non persistita: ${e.message}")
            }
            BlackBox.log("RECENTS", "tracker reset → count 0")
            publishLocked(emptySet())
        }
    }

    /// Punto UNICO di pubblicazione del set (chiamare SOTTO [stateLock]):
    /// swap del volatile + push con seq monotono nello stesso punto — count
    /// e seq del payload sono catturati atomicamente, mai un count vecchio
    /// con un seq nuovo.
    private fun publishLocked(next: Set<String>) {
        tracked = next
        notifyCountChanged(next.size, mutationSeq.incrementAndGet())
    }

    /// Push del conteggio al Dart via EventChannel: il badge del launcher si
    /// aggiorna appena il set cambia (il sync gira mentre le recents sono
    /// ancora aperte) invece di aspettare il pull al resume — era la
    /// "lentezza" percepita. Safe da qualunque thread (sendEvent posta sul
    /// main handler) e no-op senza listener.
    private fun notifyCountChanged(count: Int, seq: Long) {
        try {
            ServiceEventChannel.sendEvent(
                JSONObject()
                    .put("type", "OPEN_APPS_COUNT")
                    .put("count", count)
                    .put("seq", seq)
                    .toString(),
            )
        } catch (_: Exception) {
        }
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
    /// reset, mai prima dell'ultimo sync con le card (floor SENZA overlap:
    /// il sync è verità puntuale, l'overlap lo bucherebbe di 2s e gli
    /// ACTIVITY_RESUMED appena precedenti risusciterebbero le schede chiuse),
    /// e incrementale rispetto all'ultima sweep (con overlap anti-gap).
    internal fun sweepWindowStartMs(
        bootWallMs: Long,
        resetWallMs: Long,
        lastSweepEndWallMs: Long,
        overlapMs: Long,
        recentsSyncFloorWallMs: Long,
    ): Long = maxOf(
        bootWallMs,
        resetWallMs,
        recentsSyncFloorWallMs,
        if (lastSweepEndWallMs > 0) lastSweepEndWallMs - overlapMs else 0L,
    )

    /// PURO: l'evento RESUMED va ignorato come "resume fantasma" post
    /// clear-all? Solo entro la grazia e solo per i package che il reset ha
    /// appena azzerato — un'app diversa aperta subito dopo il reset conta,
    /// e la stessa app ri-aperta DOPO la grazia torna a contare.
    internal fun isPostResetGhost(
        pkg: String,
        eventWallMs: Long,
        graceEndWallMs: Long,
        clearedAtReset: Set<String>,
    ): Boolean = eventWallMs < graceEndWallMs && clearedAtReset.contains(pkg)

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
        tracked = emptySet()
        mutationSeq.set(0)
        launchableCache.clear()
        lastSweepEndWallMs = 0L
        lastSweepUptimeMs = 0L
        resetWallMs = -1L
        muteSyncUntilUptimeMs = 0L
        lastFreshPruneUptimeMs = 0L
        recentsSyncFloorWallMs = 0L
        clearedAtReset = emptySet()
        resetGraceEndWallMs = 0L
        resetGraceEndUptimeMs = 0L
    }

    internal fun debugTrackedSnapshot(): Set<String> = tracked
    internal fun debugLastSweepEndWallMs(): Long = lastSweepEndWallMs
    internal fun debugRecentsSyncFloorWallMs(): Long = recentsSyncFloorWallMs
    internal fun debugMutationSeq(): Long = mutationSeq.get()
}
