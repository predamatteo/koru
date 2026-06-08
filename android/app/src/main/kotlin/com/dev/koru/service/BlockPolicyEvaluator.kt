package com.dev.koru.service

import com.dev.koru.db.NativeAppRelation
import com.dev.koru.db.NativeInterval
import com.dev.koru.db.NativeProfile
import com.dev.koru.overlay.BlockReason

/**
 * Motore di DECISIONE puro del blocking engine di Koru.
 *
 * ## Perché esiste (ARCH-01 / CR-01..CR-07)
 * Prima di questo refactor la stessa decisione "questo pkg/sezione/sito va
 * bloccato ORA?" era duplicata a copia-incolla in 4 punti:
 *   - [KoruAccessibilityService.checkAppBlocking]
 *   - [KoruAccessibilityService.checkInAppContentBlocking]
 *   - [KoruAccessibilityService.checkWebsiteBlocking]
 *   - [LockRunnable.checkAndBlock] (backup polling)
 * più il "active now" lato UI in `active_profile_provider.dart`. Le copie
 * divergevano in continuazione (boundary degli intervalli half-open vs chiusi,
 * wifi solo su a11y, focus mancante nel backup, bypass di sezione non scoped):
 * ogni divergenza è un buco di enforcement che l'utente può sfruttare per
 * aggirare i propri limiti.
 *
 * Questo oggetto è l'UNICA fonte di verità della decisione. È **puro**: non
 * fa NESSUNA chiamata Android (niente `Calendar`, `WifiManager`,
 * `System.currentTimeMillis`, niente DB). Tutto l'ambiente — clock, giorno
 * corrente, SSID wifi, e soprattutto lo stato di bypass — viene INIETTATO via
 * [BlockQuery]. Così è testabile con JUnit puro (niente Robolectric) e gli
 * adapter restano i soli responsabili dei side-effect (overlay, HOME, log DB).
 *
 * Gli adapter costruiscono una [BlockQuery], chiamano [evaluate], e fanno il
 * rendering del [BlockDecision] risultante con gli stessi
 * `OverlayManager.show` / `performGoHome` / logging di prima.
 *
 * REGOLA per ogni nuovo decision site: DEVE passare da qui. Non aggiungere
 * un nuovo ramo `if (...)` di blocco in un adapter — estendi [evaluate] e i
 * suoi test (vedi `BlockPolicyParityTest`).
 */

/** Esito della valutazione di una [BlockQuery]. */
sealed interface BlockDecision {
    /** Nessun blocco: l'app/sezione/sito può restare in foreground. */
    object Allow : BlockDecision

    /**
     * Bloccare. L'adapter usa questi campi per scegliere copy/overlay/log,
     * ma NON ricalcola la decisione.
     *
     * @param reason determina copy/icona dell'overlay (riusa [BlockReason]).
     * @param profileId profilo che blocca, o `null` per i blocchi globali
     *   (focus, daily limit) che non sono profile-scoped.
     * @param relation la [NativeAppRelation] sorgente (per overlayConfigJson /
     *   blockedSectionsJson), quando disponibile.
     * @param bypassScopeDomain scope del bypass "Open anyway": per i siti è il
     *   name della regola, per le sezioni è `section:<wireId>`, altrimenti null
     *   (= bypass per-app sull'intero package).
     * @param isStrictLimit / todayMs / limitMs metadati del cap (solo
     *   [BlockReason.USAGE_LIMIT]).
     */
    data class Block(
        val reason: BlockReason,
        val profileId: Int? = null,
        val profileTitle: String,
        val profileEmoji: String? = null,
        val relation: NativeAppRelation? = null,
        val bypassScopeDomain: String? = null,
        val isStrictLimit: Boolean = false,
        val todayMs: Long = 0L,
        val limitMs: Long = 0L,
    ) : BlockDecision
}

/**
 * Tutti gli input della decisione, già letti dall'ambiente dall'adapter.
 *
 * Nota di design: [bypassReasonFor] NON ha default → ometterlo è un errore di
 * compilazione. È intenzionale: il bypass è reason-aware e dual-clock (vedi
 * [OverlayManager.bypassReason] / `BypassStore.isActive`), quindi la sua
 * verifica DEVE restare nello store layer; l'evaluator non deve mai "indovinare"
 * un default che salterebbe il check dual-clock. La lambda chiude su
 * `OverlayManager.bypassReason` con lo scope giusto (null = intero pkg, il name
 * della regola per i siti, `section:<wireId>` per le sezioni).
 *
 * @param limitTodayMs già la variante GUARDATA (SEC-03, anti clock-backward).
 * @param focusShouldBlock già `qbSnapshot.shouldBlock(pkg, nowWall)`.
 * @param todayDayFlag il singolo bit del giorno corrente (vedi DayFlags lato Dart).
 * @param websiteScopeDomain non-null solo quando l'adapter ha già un match
 *   sito (name della regola, lowercased/trimmed) → l'evaluator applica solo
 *   active-now + bypass guard.
 * @param sectionWireId non-null solo per il check sezioni in-app.
 */
data class BlockQuery(
    val packageName: String,
    val profiles: List<NativeProfile>,
    val profileApps: Map<Int, List<NativeAppRelation>>,
    val profileIntervals: Map<Int, List<NativeInterval>>,
    val profileWifis: Map<Int, Set<String>>,
    val limitMinutes: Int,
    val isLimitStrict: Boolean,
    val limitTodayMs: Long,
    val focusShouldBlock: Boolean,
    val bypassReasonFor: (scopeDomain: String?) -> BlockReason?,
    val nowWallMs: Long,
    val nowMinutesOfDay: Int,
    val todayDayFlag: Int,
    val currentWifiSsid: String?,
    val websiteScopeDomain: String? = null,
    val sectionWireId: String? = null,
)

object BlockPolicyEvaluator {

    /** Bit `PROFILE_TYPE_TIME`, allineato a [KoruAccessibilityService.PROFILE_TYPE_TIME]. */
    private const val PROFILE_TYPE_TIME = 1

    /**
     * Un profilo è "attivo ORA"? Reference di correttezza liftata dal path
     * accessibility (era la sua `isProfileActiveNow`, l'unica implementazione
     * corretta), con l'ambiente iniettato.
     *
     * Ordine dei guard (tutti in AND): pausa → giorno → onUntil → finestra
     * temporale → wifi. Manteniamo il check `pausedUntil` anche se la SQL lo
     * pre-filtra (`paused_until >= 0`): serve ai test unitari e fa fail-secure.
     *
     * NON consultiamo `isLocked`/`lockedUntil`: preserva il comportamento
     * corrente (il lockout è un concetto separato dall'enforcement orario).
     */
    fun isProfileActiveNow(
        profile: NativeProfile,
        intervals: List<NativeInterval>,
        wifiSet: Set<String>?,
        nowWallMs: Long,
        nowMinutesOfDay: Int,
        todayDayFlag: Int,
        currentWifiSsid: String?,
    ): Boolean {
        // Pausa: <0 = disabilitato a tempo indeterminato; >0 e nel futuro =
        // in pausa fino a quel wall time.
        if (profile.pausedUntil < 0) return false
        if (profile.pausedUntil > 0 && profile.pausedUntil > nowWallMs) return false
        // Giorno della settimana.
        if (profile.dayFlags and todayDayFlag == 0) return false
        // onUntil: scadenza assoluta dell'attivazione manuale ("on" fino a X).
        if (profile.onUntil > 0 && nowWallMs > profile.onUntil) return false
        // Finestra temporale: se il profilo ha il tipo TIME e intervals
        // abilitati, ORA deve cadere in almeno uno (cross-midnight supportato).
        val hasTimeType = (profile.typeCombinations and PROFILE_TYPE_TIME) != 0
        if (hasTimeType && intervals.isNotEmpty() &&
            intervals.none { isNowInInterval(nowMinutesOfDay, it.fromMinutes, it.toMinutes) }
        ) {
            return false
        }
        // Wifi: se il profilo ha almeno un SSID vincolato, attivo solo se
        // l'SSID corrente matcha. SSID non leggibile (permesso location
        // mancante → null) ⇒ "no match" ⇒ profilo inattivo (fail-secure).
        if (wifiSet != null && wifiSet.isNotEmpty() &&
            (currentWifiSsid == null || currentWifiSsid !in wifiSet)
        ) {
            return false
        }
        return true
    }

    /**
     * La decisione di blocco completa. Ordine dei rami CROSS-CHECKATO contro
     * tutte e 3 le funzioni accessibility: nessun guard è stato perso, e in
     * caso di ambiguità si tende verso "blocked" (l'avversario è l'utente che
     * cerca di aggirare i propri limiti).
     *
     * 1. **Focus / quick-block**: vince su tutto (il backup ora lo applica
     *    anch'esso — CR-01).
     * 2. **Daily limit**: cap cumulativo. Valutato PRIMA del bypass di profilo
     *    (un "Open anyway" su un blocco di profilo non ricarica il budget).
     *    STRICT ⇒ ignora QUALSIASI bypass. NON-strict ⇒ sospeso solo da un
     *    bypass NATO dal limite (USAGE_LIMIT / BYPASS_EXPIRED).
     * 3. **Bypass di profilo attivo** (whole-app) ⇒ Allow short-circuit: il cap
     *    è già stato valutato sopra; l'adapter fa il bookkeeping di auto-revoke.
     * 4. **APP match**: per ogni profilo attivo ORA, blocklist contiene /
     *    allowlist (non vuota && non contiene).
     * 5. **SECTION match** (solo se [BlockQuery.sectionWireId] != null): profilo
     *    attivo, relation esiste, app NON bloccata interamente
     *    (`!relation.isEnabled`), blockedSectionsJson contiene il wireId.
     *    CR-07: rispetta il bypass scoped `section:<wireId>`.
     * 6. **WEBSITE match** (solo se [BlockQuery.websiteScopeDomain] != null;
     *    l'adapter ha già fatto girare WebsiteMatcher): rispetta il bypass
     *    per-dominio.
     * 7. else Allow.
     */
    fun evaluate(q: BlockQuery): BlockDecision {
        // 1) Focus / quick-block.
        if (q.focusShouldBlock) {
            return BlockDecision.Block(
                reason = BlockReason.FOCUS_MODE,
                profileTitle = "Focus session",
                profileEmoji = "🎯", // 🎯
            )
        }

        // 2) Daily limit. limitBypassActive = un bypass nato DAL limite stesso.
        val limitBypassActive = q.bypassReasonFor(null).let {
            it == BlockReason.USAGE_LIMIT || it == BlockReason.BYPASS_EXPIRED
        }
        if (q.limitMinutes > 0 && q.limitTodayMs >= q.limitMinutes * 60_000L &&
            (q.isLimitStrict || !limitBypassActive)
        ) {
            return BlockDecision.Block(
                reason = BlockReason.USAGE_LIMIT,
                profileTitle = if (q.isLimitStrict) "Daily limit · strict" else "Daily limit",
                profileEmoji = "⏳", // ⏳
                isStrictLimit = q.isLimitStrict,
                todayMs = q.limitTodayMs,
                limitMs = q.limitMinutes * 60_000L,
            )
        }

        // 3) Bypass di profilo (whole-app) attivo ⇒ Allow. Il cap è già stato
        // valutato sopra e non scavalcato; qui sopprimiamo il re-block per la
        // durata scelta (l'adapter traccia il pkg per l'auto-revoke).
        if (q.bypassReasonFor(null) != null) return BlockDecision.Allow

        // 4) APP match: per ogni profilo attivo ORA.
        for (profile in q.profiles) {
            if (!isActive(q, profile)) continue
            val apps = q.profileApps[profile.id] ?: emptyList()
            val enabledApps = apps.filter { it.isEnabled }.map { it.packageName }
            val shouldBlock = when (profile.blockingMode) {
                0 -> enabledApps.contains(q.packageName)
                1 -> enabledApps.isNotEmpty() && !enabledApps.contains(q.packageName)
                else -> false
            }
            if (shouldBlock) {
                val relation = apps.firstOrNull { it.packageName == q.packageName }
                return BlockDecision.Block(
                    reason = BlockReason.APP_BLOCKED,
                    profileId = profile.id,
                    profileTitle = profile.title,
                    profileEmoji = profile.emoji,
                    relation = relation,
                )
            }
        }

        // 5) SECTION match (in-app content). Solo se l'adapter ha rilevato una
        // sezione (sectionWireId != null).
        val sectionWireId = q.sectionWireId
        if (sectionWireId != null) {
            for (profile in q.profiles) {
                if (!isActive(q, profile)) continue
                val apps = q.profileApps[profile.id] ?: continue
                val relation = apps.firstOrNull { it.packageName == q.packageName } ?: continue
                // App bloccata interamente ⇒ la gestisce il path APP, non qui.
                if (relation.isEnabled) continue
                val json = relation.blockedSectionsJson ?: continue
                if (!json.contains(sectionWireId)) continue
                // CR-07: bypass scoped alla sezione. Senza questo guard un
                // "Open anyway" sulla sezione non aveva effetto (il bypass era
                // keyed a section:<wireId> ma il check non lo leggeva).
                val scope = "section:$sectionWireId"
                if (q.bypassReasonFor(scope) != null) return BlockDecision.Allow
                return BlockDecision.Block(
                    reason = BlockReason.SECTION_BLOCKED,
                    profileId = profile.id,
                    profileTitle = profile.title,
                    profileEmoji = profile.emoji,
                    relation = relation,
                    bypassScopeDomain = scope,
                )
            }
        }

        // 6) WEBSITE match. L'adapter ha già fatto girare BrowserUrlDetector +
        // WebsiteMatcher.firstMatch e passa il name della regola matchata
        // (lowercased/trimmed) come websiteScopeDomain, con `profiles`
        // ristretto al solo profilo che ha fatto match.
        val websiteScope = q.websiteScopeDomain
        if (websiteScope != null) {
            for (profile in q.profiles) {
                if (!isActive(q, profile)) continue
                // Bypass per-dominio: "Open anyway" su QUESTO sito sblocca solo
                // questo dominio, gli altri restano bloccati.
                if (q.bypassReasonFor(websiteScope) != null) return BlockDecision.Allow
                return BlockDecision.Block(
                    reason = BlockReason.WEBSITE_BLOCKED,
                    profileId = profile.id,
                    profileTitle = profile.title,
                    profileEmoji = profile.emoji,
                    bypassScopeDomain = websiteScope,
                )
            }
        }

        return BlockDecision.Allow
    }

    /** Overload interno: applica [isProfileActiveNow] usando l'env di [q]. */
    private fun isActive(q: BlockQuery, profile: NativeProfile): Boolean =
        isProfileActiveNow(
            profile = profile,
            intervals = q.profileIntervals[profile.id] ?: emptyList(),
            wifiSet = q.profileWifis[profile.id],
            nowWallMs = q.nowWallMs,
            nowMinutesOfDay = q.nowMinutesOfDay,
            todayDayFlag = q.todayDayFlag,
            currentWifiSsid = q.currentWifiSsid,
        )

    /**
     * Il minuto-del-giorno corrente cade nell'intervallo [fromMinutes, ...)?
     * Semantica CANONICA (allineata a `ScheduleUtils.isNowInRange` lato Dart):
     *   - `from == to` ⇒ 24h (sempre dentro);
     *   - `from <  to` ⇒ half-open `[from, to)` (to escluso);
     *   - `from >  to` ⇒ cross-midnight (es. 22:00→06:00): dentro se
     *     `now >= from || now < to`.
     */
    internal fun isNowInInterval(nowMinutes: Int, fromMinutes: Int, toMinutes: Int): Boolean =
        when {
            fromMinutes == toMinutes -> true
            fromMinutes < toMinutes -> nowMinutes in fromMinutes until toMinutes
            else -> nowMinutes >= fromMinutes || nowMinutes < toMinutes
        }

    /**
     * Minuti (1..1440) dal minuto-del-giorno [nowMinutes] al PROSSIMO confine
     * (inizio O fine) tra gli [intervals], con wrap a mezzanotte. `null` se non
     * esiste alcun confine significativo (lista vuota, o solo intervalli 24h
     * `from == to`).
     *
     * Serve a schedulare un re-check del blocco quando un confine orario viene
     * attraversato MENTRE l'app è già in foreground: a quel confine non arriva
     * alcun `TYPE_WINDOW_STATE_CHANGED`, quindi
     * [KoruAccessibilityService.checkAppBlocking] non verrebbe mai richiamato
     * spontaneamente (stesso blind-spot già coperto per bypass-TTL e
     * daily-limit). Un confine che cade ESATTAMENTE ORA è mappato a 1440
     * (= fra 24h), non a 0: "ora" la decisione è già stata presa da questo
     * stesso check, il prossimo utile è il giro successivo.
     */
    internal fun minutesUntilNextBoundary(nowMinutes: Int, intervals: List<NativeInterval>): Int? {
        var best: Int? = null
        for (iv in intervals) {
            if (iv.fromMinutes == iv.toMinutes) continue // 24h: nessun confine
            for (boundary in intArrayOf(iv.fromMinutes, iv.toMinutes)) {
                val delta = ((boundary - nowMinutes) % 1440 + 1440) % 1440 // 0..1439
                val d = if (delta == 0) 1440 else delta
                if (best == null || d < best) best = d
            }
        }
        return best
    }
}
