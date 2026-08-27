import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/constants/layout.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../platform/blocking_channel.dart';
import '../../../providers/app_limits_provider.dart';
import '../../../providers/app_list_provider.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/koru_pull_to_refresh.dart';
import '../../../widgets/unlock_challenge_dialog.dart';

/// Imposta un limite giornaliero (minuti/giorno) per app specifiche.
///
/// ## Ordinamento
/// Le app con un limite attivo restano in cima — è il motivo per cui la
/// schermata esiste, e sprofondarle sotto trenta app non correlate la
/// trasformerebbe da editor dei propri limiti a elenco. Sotto, l'ordine è per
/// **tempo d'uso di oggi** decrescente: chi arriva qui cerca l'app che sta
/// consumando la giornata, non quella che comincia per A.
///
/// L'ordine è uno **snapshot**, non un calcolo per frame: l'utilizzo cresce di
/// continuo e una lista che si riordina da sola fa atterrare i tap sull'app
/// sbagliata mentre la si scorre.
///
/// ## Caricamento
/// L'uso arriva da [todayUsageMsByPackageProvider]: UNA chiamata nativa per
/// tutte le app. La lista si dipinge 25 righe alla volta — le righe successive
/// entrano scorrendo. La ricerca invece lavora sempre sull'elenco INTERO,
/// altrimenti l'app che stai cercando sparisce proprio perché è oltre il
/// taglio.
/// Ordine di visualizzazione della lista: prima i limiti attivi (per minuti
/// crescenti, il più stretto in cima), poi tutto il resto per uso di oggi
/// decrescente. A parità — e a zero minuti sono la maggioranza — l'ordine
/// alfabetico tiene la lista stabile fra un rebuild e l'altro.
///
/// Funzione pura e pubblica per un motivo solo: queste tre priorità sono
/// l'unica cosa che rende la schermata usabile, e vanno verificate senza
/// montare nulla.
List<InstalledAppInfo> sortAppsForLimits({
  required List<InstalledAppInfo> apps,
  required Map<String, AppLimitConfig> limits,
  required Map<String, int> usageMs,
}) {
  final sorted = [...apps];
  sorted.sort((a, b) {
    final al = limits[a.packageName]?.minutes ?? 0;
    final bl = limits[b.packageName]?.minutes ?? 0;
    if ((al > 0) != (bl > 0)) return al > 0 ? -1 : 1;
    if (al > 0 && bl > 0 && al != bl) return al.compareTo(bl);
    final au = usageMs[a.packageName] ?? 0;
    final bu = usageMs[b.packageName] ?? 0;
    if (au != bu) return bu.compareTo(au);
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });
  return sorted;
}

class AppLimitsScreen extends ConsumerStatefulWidget {
  const AppLimitsScreen({super.key});

  @override
  ConsumerState<AppLimitsScreen> createState() => _AppLimitsScreenState();
}

class _AppLimitsScreenState extends ConsumerState<AppLimitsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  /// Quante righe sono dipinte. Cresce a blocchi mentre si scorre; torna al
  /// valore iniziale a ogni cambio di ricerca, così un nuovo elenco parte
  /// sempre dall'alto.
  static const _pageSize = 25;
  int _visibleCount = _pageSize;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    setState(() {
      _query = v;
      _visibleCount = _pageSize;
    });
  }

  Future<void> _editLimit(
    String pkg,
    String label,
    AppLimitConfig? current,
  ) async {
    final chosen = await showDialog<AppLimitConfig?>(
      context: context,
      builder: (ctx) => _LimitPickerDialog(label: label, initial: current),
    );
    if (chosen == null) return;
    if (!mounted) return;

    // Il gate legge la config SALVATA, mai quella che esce dal dialog: se
    // leggesse `chosen.challengeLock`, basterebbe spegnere l'interruttore
    // dentro al dialog per uscire senza sfida — cioè la protezione si
    // disattiverebbe da sé.
    if (_weakens(current, chosen)) {
      final ok = await requireLimitUnlockChallenge(
        context,
        ref,
        action: AppLocalizations.of(context).appLimitsActionLoosen(label),
      );
      if (!ok) return;
    }

    // `chosen.minutes == 0` è il sentinel "remove limit" emesso dal dialog.
    if (chosen.minutes <= 0) {
      await ref.read(appLimitsProvider.notifier).clear(pkg);
    } else {
      await ref.read(appLimitsProvider.notifier).setLimit(
            pkg,
            chosen.minutes,
            strict: chosen.strict,
            challengeLock: chosen.challengeLock,
          );
    }
  }

  /// Se il cambiamento richiesto INDEBOLISCE un limite protetto.
  ///
  /// Solo questa direzione è gateata — la stessa invariante dei profili e
  /// dello strict mode. Impostare un limite per la prima volta, abbassare i
  /// minuti, accendere lo strict o accendere il lock stesso restano gratis.
  static bool _weakens(AppLimitConfig? current, AppLimitConfig chosen) {
    if (current == null || current.minutes <= 0) return false;
    if (!current.challengeLock) return false;
    return chosen.minutes <= 0 ||
        chosen.minutes > current.minutes ||
        (current.strict && !chosen.strict) ||
        !chosen.challengeLock;
  }

  @override
  Widget build(BuildContext context) {
    final limitsAsync = ref.watch(appLimitsProvider);
    final appsAsync = ref.watch(installedAppsProvider);
    // La LISTA arriva da [pickerAppsProvider] (niente altri launcher, niente
    // Koru); `appsAsync` resta solo per gli stati loading/error.
    final apps = ref.watch(pickerAppsProvider);
    // `.valueOrNull` e non `.when`: la lista si dipinge subito (ordinata per
    // limite e alfabeto) e si riordina quando l'unica chiamata nativa risponde,
    // invece di tenere uno spinner davanti a dati che ci sono già.
    final usageMs =
        ref.watch(todayUsageMsByPackageProvider).valueOrNull ?? const {};

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appLimitsTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.commonSearchApps,
                prefixIcon: const Icon(
                  Icons.search,
                  color: KoruColors.textSecondary,
                ),
                filled: true,
                fillColor: KoruColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: KoruPullToRefresh(
        child: appsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (_) {
            final limits =
                limitsAsync.valueOrNull ?? const <String, AppLimitConfig>{};
            final q = _query.trim().toLowerCase();
            // Il filtro si applica all'elenco INTERO e l'ordinamento viene
            // prima del taglio: paginare e poi ordinare mostrerebbe le prime
            // 25 in ordine alfabetico riordinate fra loro — plausibile e
            // sbagliato.
            final filtered = q.isEmpty
                ? apps
                : apps
                    .where(
                      (a) =>
                          a.label.toLowerCase().contains(q) ||
                          a.packageName.toLowerCase().contains(q),
                    )
                    .toList(growable: false);
            final sorted = sortAppsForLimits(
              apps: filtered,
              limits: limits,
              usageMs: usageMs,
            );
            final shown = sorted.length < _visibleCount
                ? sorted.length
                : _visibleCount;
            final hasMore = shown < sorted.length;

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 8, 0, kBottomNavClearance),
              // header + righe + eventuale sentinella di caricamento
              itemCount: shown + (hasMore ? 2 : 1),
              itemBuilder: (context, i) {
                if (i == 0) return const _Intro();
                if (i == shown + 1) return _LoadMoreSentinel(onVisible: _showMore);
                final app = sorted[i - 1];
                final cfg = limits[app.packageName];
                return _AppLimitRow(
                  label: app.label,
                  packageName: app.packageName,
                  limit: cfg,
                  usedMinutes: ((usageMs[app.packageName] ?? 0) / 60000).round(),
                  onTap: () => _editLimit(app.packageName, app.label, cfg),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showMore() {
    if (!mounted) return;
    setState(() => _visibleCount += _pageSize);
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Text(
        AppLocalizations.of(context).appLimitsIntro,
        style: const TextStyle(
          color: KoruColors.textSecondary,
          height: 1.4,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Sentinella in fondo alla pagina: quando entra nella lista chiede il blocco
/// successivo. Il `setState` è differito al post-frame perché ampliare la
/// pagina mentre la lista si sta costruendo è una modifica dell'albero durante
/// il build.
class _LoadMoreSentinel extends StatefulWidget {
  const _LoadMoreSentinel({required this.onVisible});

  final VoidCallback onVisible;

  @override
  State<_LoadMoreSentinel> createState() => _LoadMoreSentinelState();
}

class _LoadMoreSentinelState extends State<_LoadMoreSentinel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisible();
    });
  }

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}

/// Row con icon + label + tempo d'uso di oggi, e — se c'è un limite — barra di
/// progresso usato/cap, badge minuti e le icone di strict / challenge lock.
class _AppLimitRow extends StatelessWidget {
  const _AppLimitRow({
    required this.label,
    required this.packageName,
    required this.limit,
    required this.usedMinutes,
    required this.onTap,
  });

  final String label;
  final String packageName;
  final AppLimitConfig? limit;

  /// Minuti di foreground di oggi. Arriva dalla mappa bulk, non da una
  /// chiamata per riga: [todayUsageMsByPackageProvider] spiega perché.
  /// L'arrotondamento `(ms / 60000).round()` è un contratto di parità col
  /// widget nativo (`UsageWidgetModel.toMinutes`), non una preferenza.
  final int usedMinutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cfg = limit;
    final hasLimit = cfg != null && cfg.minutes > 0;
    final limitMinutes = cfg?.minutes ?? 0;
    final progress = hasLimit ? (usedMinutes / limitMinutes).clamp(0.0, 1.0) : 0.0;
    final exceeded = hasLimit && usedMinutes >= limitMinutes;
    final barColor = exceeded
        ? KoruColors.danger
        : (progress > 0.8 ? KoruColors.secondary : KoruColors.primary);
    final l10n = AppLocalizations.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            AppIcon(packageName: packageName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      if (hasLimit && cfg.strict) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: KoruColors.primary,
                        ),
                      ],
                      if (hasLimit && cfg.challengeLock) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.extension_outlined,
                          size: 14,
                          color: KoruColors.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasLimit
                        ? l10n.appLimitsUsedOfCap(usedMinutes, limitMinutes)
                        : _usageLabel(usedMinutes, l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: exceeded
                          ? KoruColors.danger
                          : KoruColors.textSecondary,
                      fontSize: 11,
                      fontWeight:
                          exceeded ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (hasLimit) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: KoruColors.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            hasLimit
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: KoruColors.primary.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.appLimitsBadgeMinutes(limitMinutes),
                      style: const TextStyle(
                        color: KoruColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.chevron_right,
                    color: KoruColors.textSecondary,
                  ),
          ],
        ),
      ),
    );
  }

  /// Sottotitolo delle app senza limite. A zero minuti dice "Non usata oggi"
  /// invece di "0 min oggi": è la stessa informazione, ma non sembra un dato
  /// mancante.
  static String _usageLabel(int minutes, AppLocalizations l10n) {
    if (minutes <= 0) return l10n.appLimitsNotUsedToday;
    if (minutes < 60) return l10n.appLimitsMinutesToday(minutes);
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0
        ? l10n.appLimitsHoursToday(h)
        : l10n.appLimitsHoursMinutesToday(h, m);
  }
}

/// Dialog per impostare minuti + strict + challenge lock.
///
/// È volutamente **muto**: non conosce Riverpod e non mostra sfide, ritorna
/// solo un [AppLimitConfig]. La sfida di sblocco la fa partire la schermata
/// DOPO che il dialog è stato chiuso — chiamarla da qui significherebbe
/// attendere una rotta annidata da un widget che sta per essere smontato.
class _LimitPickerDialog extends StatefulWidget {
  const _LimitPickerDialog({required this.label, required this.initial});

  final String label;
  final AppLimitConfig? initial;

  @override
  State<_LimitPickerDialog> createState() => _LimitPickerDialogState();
}

class _LimitPickerDialogState extends State<_LimitPickerDialog> {
  late double _minutes;
  late bool _strict;
  late bool _challengeLock;
  static const _max = 360.0; // 6h
  static const _presets = <int>[15, 30, 60, 120];

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _minutes = (initial?.minutes ?? 30).clamp(5, _max.toInt()).toDouble();
    // Default per nuovi limiti: entrambe le protezioni accese. Chi imposta un
    // cap sta chiedendo attrito; toglierlo deve essere una scelta esplicita.
    _strict = initial?.strict ?? true;
    _challengeLock = initial?.challengeLock ?? true;
  }

  AppLimitConfig get _result => AppLimitConfig(
        minutes: _minutes.round(),
        strict: _strict,
        challengeLock: _challengeLock,
      );

  @override
  Widget build(BuildContext context) {
    final value = _minutes.round();
    final isExisting = (widget.initial?.minutes ?? 0) > 0;
    final l10n = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: KoruColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: KoruColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.appLimitsDailyCap.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: KoruColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              // Il numero è il protagonista del dialog: chi apre questa
              // schermata sta scegliendo una quantità, non leggendo un titolo.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                      height: 1,
                      color: KoruColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.appLimitsMinPerDay,
                    style: const TextStyle(
                      fontSize: 14,
                      color: KoruColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Slider(
                value: _minutes,
                min: 5,
                max: _max,
                divisions: ((_max - 5) / 5).round(),
                label: '$value',
                onChanged: (v) => setState(() => _minutes = v),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in _presets)
                    ChoiceChip(
                      label: Text(l10n.appLimitsPresetMinutes(p)),
                      selected: value == p,
                      onSelected: (_) =>
                          setState(() => _minutes = p.toDouble()),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _OptionTile(
                icon: Icons.lock_outline,
                title: l10n.appLimitsStrictTitle,
                subtitle: _strict
                    ? l10n.appLimitsStrictOn
                    : l10n.appLimitsStrictOff,
                value: _strict,
                onChanged: (v) => setState(() => _strict = v),
              ),
              const SizedBox(height: 8),
              _OptionTile(
                icon: Icons.extension_outlined,
                title: l10n.appLimitsChallengeLockTitle,
                subtitle: _challengeLock
                    ? l10n.appLimitsChallengeLockOn
                    : l10n.appLimitsChallengeLockOff,
                value: _challengeLock,
                onChanged: (v) => setState(() => _challengeLock = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (isExisting)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(
                        _result.copyWith(minutes: 0),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: KoruColors.danger,
                      ),
                      child: Text(l10n.commonRemove),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_result),
                    child: Text(l10n.commonSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Riga interruttore del dialog: icona + titolo + una riga che dice cosa
/// succede DAVVERO in quello stato, non cosa fa l'opzione in astratto.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value
          ? KoruColors.primaryContainer.withAlpha(70)
          : KoruColors.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 18,
                color: value ? KoruColors.primary : KoruColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: KoruColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: KoruColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
