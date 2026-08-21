import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/constants/profile_types.dart';
import '../../../../platform/blocking_channel.dart';
import '../../../providers/app_list_provider.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/screen_time_provider.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/koru_pull_to_refresh.dart';
import '../../../widgets/unlock_challenge_dialog.dart';

/// Seleziona le app da bloccare (blocklist) o consentire (allowlist) per un profilo.
class SetBlockedAppsScreen extends ConsumerStatefulWidget {
  const SetBlockedAppsScreen({super.key, required this.profileId});

  final int profileId;

  @override
  ConsumerState<SetBlockedAppsScreen> createState() =>
      _SetBlockedAppsScreenState();
}

class _SetBlockedAppsScreenState extends ConsumerState<SetBlockedAppsScreen> {
  Set<String> _selected = <String>{};
  bool _loaded = false;
  final _searchController = TextEditingController();
  String _query = '';

  /// Selezione com'era all'apertura, il profilo era acceso, e in che modalità:
  /// insieme dicono se il salvataggio sta INDEBOLENDO la protezione e quindi se
  /// deve passare dalla sfida di sblocco. Vedi [_weakensProtection].
  Set<String> _initialSelection = const <String>{};
  bool _profileEnabled = false;
  int _blockingMode = BlockingMode.blocklist;

  /// Le app "più usate della settimana" da mostrare in cima alla lista, in
  /// ordine di utilizzo desc. `null` finché il ranking non è disponibile
  /// (vedi [_ensureSuggestions]).
  List<String>? _suggested;

  @override
  void initState() {
    super.initState();
    // Pre-fetch della lista app: anche se il provider è cached, la prima
    // lettura (primo entering) è asincrona — triggeriamo subito così Flutter
    // inizia il MethodChannel call in parallelo alla transition di navigazione.
    // Stesso discorso per il ranking settimanale (query UsageStatsManager):
    // parte insieme allo scan del PackageManager invece che dopo.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(installedAppsProvider);
      ref.read(weeklyTopAppsProvider);
      _hydrate();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    if (_loaded) return;
    // refresh forzato: profileByIdProvider è una FutureProvider cached,
    // quindi senza invalidation espliciva ritornerebbe stale data tra
    // visite ripetute.
    final profile = await ref.refresh(
      profileByIdProvider(widget.profileId).future,
    );
    if (!mounted) return;
    setState(() {
      _loaded = true;
      // Filtra solo le relations effettivamente attive: senza filtro
      // includevamo anche relations create per in-app sections o overlay
      // custom (isEnabled=false), che apparivano "pre-selezionate" senza
      // essere realmente bloccate.
      _selected =
          profile?.apps
              .where((a) => a.isEnabled)
              .map((a) => a.packageName)
              .toSet() ??
          <String>{};
      _initialSelection = {..._selected};
      _profileEnabled = profile?.isEnabled ?? false;
      _blockingMode = profile?.blockingMode ?? BlockingMode.blocklist;
    });
  }

  /// True se salvare questa selezione lascia l'utente **meno** protetto di
  /// com'era entrando.
  ///
  /// Il verso dipende dalla modalità del profilo, ed è facile sbagliarlo:
  /// in *blocklist* le app selezionate sono quelle bloccate, quindi togliere
  /// app allenta; in *allowlist* sono quelle permesse, quindi è **aggiungerle**
  /// che allenta. Su un profilo spento non c'è niente da allentare.
  bool _weakensProtection() {
    if (!_profileEnabled) return false;
    return _blockingMode == BlockingMode.allowlist
        ? _selected.difference(_initialSelection).isNotEmpty
        : _initialSelection.difference(_selected).isNotEmpty;
  }

  Future<void> _save() async {
    if (_weakensProtection()) {
      final granted = await requireUnlockChallenge(
        context,
        ref,
        action: 'togliere protezione a un profilo acceso',
      );
      if (!granted) return;
      if (!mounted) return;
    }
    await ref
        .read(profileRepositoryProvider)
        .setAppsForProfile(widget.profileId, _selected.toList(growable: false));
    // Invalidate profileByIdProvider: l'editor (e ulteriori visite a
    // questa screen) devono vedere i dati appena salvati, non lo snapshot
    // cached.
    ref.invalidate(profileByIdProvider(widget.profileId));
    if (mounted) context.pop();
  }

  List<InstalledAppInfo> _filter(List<InstalledAppInfo> apps) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return apps;
    return apps
        .where(
          (a) =>
              a.label.toLowerCase().contains(q) ||
              a.packageName.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  /// Calcola UNA SOLA VOLTA i suggerimenti "most used this week", appena il
  /// ranking settimanale è disponibile.
  ///
  /// Il congelamento è intenzionale: ricalcolandoli a ogni build, spuntare un
  /// suggerimento lo renderebbe "già selezionato" — sparirebbe da sotto il
  /// dito dell'utente e la lista scorrerebbe su. Una volta scelti, i tre
  /// restano lì finché non si esce dalla schermata.
  ///
  /// Non blocca il primo paint: se la query di UsageStatsManager è più lenta
  /// dello scan del PackageManager, la lista compare senza sezione e i
  /// suggerimenti si aggiungono quando il ranking arriva. Se il permesso
  /// Usage Access manca (provider in errore) `weekly` resta `null` e la
  /// schermata si comporta esattamente come prima.
  void _ensureSuggestions(
    List<InstalledAppInfo> apps,
    List<AppUsageInfo>? weekly,
  ) {
    if (_suggested != null || weekly == null) return;
    _suggested = mostUsedAppSuggestions(
      weeklyRanking: weekly,
      installedPackages: {for (final a in apps) a.packageName},
      alreadySelected: _selected,
    );
  }

  /// Righe della lista: i suggerimenti in cima (con le rispettive
  /// intestazioni di sezione), poi tutte le altre app in ordine alfabetico.
  ///
  /// Durante una ricerca i suggerimenti sono disattivati: chi digita sta
  /// cercando un'app precisa, e vedersi in testa tre risultati che non
  /// c'entrano con la query sarebbe solo rumore.
  List<_PickerRow> _rows(List<InstalledAppInfo> filtered) {
    final suggested = _query.trim().isEmpty
        ? (_suggested ?? const <String>[])
        : const <String>[];
    if (suggested.isEmpty) {
      return [for (final a in filtered) _PickerRow.app(a)];
    }
    final byPackage = {for (final a in filtered) a.packageName: a};
    final pinned = [
      for (final pkg in suggested)
        if (byPackage[pkg] != null) byPackage[pkg]!,
    ];
    if (pinned.isEmpty) {
      return [for (final a in filtered) _PickerRow.app(a)];
    }
    final pinnedPackages = {for (final a in pinned) a.packageName};
    return [
      const _PickerRow.header('Most used this week'),
      for (final a in pinned) _PickerRow.app(a),
      const _PickerRow.header('All apps'),
      for (final a in filtered)
        if (!pinnedPackages.contains(a.packageName)) _PickerRow.app(a),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(installedAppsProvider);
    final weekly = ref.watch(weeklyTopAppsProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select apps'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search apps',
                prefixIcon: const Icon(
                  Icons.search,
                  color: KoruColors.textSecondary,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: KoruColors.textSecondary,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
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
          data: (apps) {
            if (!_loaded) {
              return const Center(child: CircularProgressIndicator());
            }
            _ensureSuggestions(apps, weekly);
            final filtered = _filter(apps);
            if (filtered.isEmpty) {
              return Center(
                child: Text(
                  'No apps matching "$_query"',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: KoruColors.textSecondary,
                  ),
                ),
              );
            }
            final rows = _rows(filtered);
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final header = rows[i].header;
                if (header != null) return _SectionHeader(header);
                final app = rows[i].app!;
                final checked = _selected.contains(app.packageName);
                return CheckboxListTile(
                  value: checked,
                  activeColor: KoruColors.primary,
                  checkColor: KoruColors.onPrimary,
                  side: const BorderSide(
                    color: KoruColors.textSecondary,
                    width: 1.5,
                  ),
                  secondary: AppIcon(packageName: app.packageName),
                  title: Text(
                    app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: KoruColors.textSecondary,
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {
                      if (v ?? false) {
                        _selected.add(app.packageName);
                      } else {
                        _selected.remove(app.packageName);
                      }
                    });
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Una riga della lista del picker: o un'intestazione di sezione, o un'app.
/// Esattamente uno dei due campi è non-null.
class _PickerRow {
  const _PickerRow.header(this.header) : app = null;
  const _PickerRow.app(this.app) : header = null;

  final String? header;
  final InstalledAppInfo? app;
}

/// Intestazione di sezione della lista, nello stile delle label delle
/// Statistiche (maiuscolo, primary, tracking largo).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: KoruColors.primary.withAlpha(220),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
