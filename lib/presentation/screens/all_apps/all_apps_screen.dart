import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/theme/launcher_phase.dart';
import '../../../platform/blocking_channel.dart';
import '../../providers/app_list_provider.dart';
import '../../widgets/koru_pull_to_refresh.dart';
import '../../widgets/minute_tick_builder.dart';
import 'widgets/app_list_view.dart';
import 'widgets/app_search_bar.dart';
import 'widgets/fast_scroller.dart';

/// Il drawer "tutte le app".
///
/// Material 3 Expressive con i token di Koru, più tre scelte che restano
/// diverse da una lista di sistema:
///
/// - **niente AppBar.** Era il capo di una pagina di impostazioni prestato a
///   un launcher. Al suo posto una riga leggera: ora, quante app, e `Close`.
/// - **la ricerca sta in basso**, sopra la tastiera ([AppSearchBar]), e la
///   lista è ancorata al fondo: i risultati crescono verso il pollice.
/// - **la pastiglia della lettera**: mentre il dito scorre il rail A-Z, la
///   lettera corrente compare in un container tonale accanto al righello.
class AllAppsScreen extends ConsumerStatefulWidget {
  const AllAppsScreen({super.key, this.autofocusSearch = false});

  /// Quando true apre il drawer con la barra di ricerca già in focus. Usato
  /// dall'azione swipe "Ricerca app" del launcher (`/launcher/drawer?focus=search`).
  final bool autofocusSearch;

  @override
  ConsumerState<AllAppsScreen> createState() => _AllAppsScreenState();
}

class _AllAppsScreenState extends ConsumerState<AllAppsScreen>
    with WidgetsBindingObserver {
  late final ScrollController _scrollController = ScrollController();
  final Map<String, double> _sectionOffsets = {};

  /// Lettera mostrata nella pastiglia accanto al rail mentre lo si scorre.
  String? _scrubLetter;
  Timer? _scrubTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reset query al mount: copre il caso in cui il drawer sia stato
    // chiuso senza passare da `resumed` (es. HOME intent che naviga a
    // /launcher e smonta AllAppsScreen prima che l'observer scatti).
    // Senza questo, la query stale filtra già la lista alla riapertura
    // mentre il TextField è vuoto.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(appSearchQueryProvider);
      if (current.isNotEmpty) {
        ref.read(appSearchQueryProvider.notifier).state = '';
      }
    });
  }

  @override
  void dispose() {
    _scrubTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reset query quando il drawer torna in foreground dopo che l'utente
    // ha lanciato un'app. Il reset inline al tap causava flash della lista
    // completa prima che la transition a Instagram/altro completasse;
    // resettare su resume evita il flash e dà lista pulita al ritorno.
    if (state == AppLifecycleState.resumed && mounted) {
      final current = ref.read(appSearchQueryProvider);
      if (current.isNotEmpty) {
        ref.read(appSearchQueryProvider.notifier).state = '';
      }
    }
  }

  void _computeSectionOffsets(Map<String, List<InstalledAppInfo>> grouped) {
    _sectionOffsets.clear();
    // Le altezze vengono da [AppListMetrics] — la stessa fonte che
    // `AppListView` usa per disegnare. Se l'utente ha aumentato la font-scale
    // di sistema (Accessibility → Display size & text) le righe crescono, e
    // senza `TextScaler` il salto della fast-scrollbar si ancorerebbe su
    // offset sbagliati.
    final textScaler = MediaQuery.textScalerOf(context);
    final textTheme = Theme.of(context).textTheme;
    final headerHeight = AppListMetrics.headerHeight(
      textScaler,
      textTheme.titleSmall?.fontSize ?? AppListMetrics.headerFontFallback,
    );
    final tileHeight = AppListMetrics.rowHeight(
      textScaler,
      textTheme.bodyLarge?.fontSize ?? AppListMetrics.rowFontFallback,
    );
    var offset = AppListMetrics.topPadding;
    for (final entry in grouped.entries) {
      _sectionOffsets[entry.key] = offset;
      offset += headerHeight + entry.value.length * tileHeight;
    }
  }

  void _onLetterSelected(String letter) {
    _scrubTimer?.cancel();
    if (_scrubLetter != letter) setState(() => _scrubLetter = letter);

    final grouped = ref.read(groupedAppsProvider);
    _computeSectionOffsets(grouped);
    final target = _sectionOffsets[letter];
    if (target != null && _scrollController.hasClients) {
      _scrollController.animateTo(
        target.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _onScrubEnd() {
    _scrubTimer?.cancel();
    _scrubTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _scrubLetter = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Stale-while-revalidate: `skipLoadingOnRefresh`/`skipLoadingOnReload`
    // fanno sì che `.when` mostri il ramo `data` (lista cached) anche quando
    // `installedAppsProvider` è in `AsyncLoading.copyWithPrevious`
    // (smart-refresh post-resume o PACKAGE_*); lo spinner appare SOLO al
    // primo load (no previous). NON usare `unwrapPrevious()`: scarterebbe il
    // previous e rimetterebbe lo spinner ad ogni reload — era il blink di
    // 1-3s al rientro home che i fix 73d174c/e3c930d volevano togliere ma
    // ottenevano l'opposto invertendo la semantica dell'API.
    final appsAsync = ref.watch(installedAppsProvider);
    final grouped = ref.watch(groupedAppsProvider);
    final totalApps = ref.watch(visibleAppsProvider).length;
    final searching = ref.watch(appSearchQueryProvider).trim().isNotEmpty;

    return LauncherPhaseBuilder(
      builder: (context, phase) => Scaffold(
        backgroundColor: phase.background,
        body: SafeArea(
          child: Column(
            children: [
              _DrawerHeader(phase: phase, totalApps: totalApps),
              Expanded(
                child: appsAsync.when(
                  skipLoadingOnRefresh: true,
                  skipLoadingOnReload: true,
                  loading: () => Center(
                    child: CircularProgressIndicator(color: phase.accent),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        err.toString(),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: KoruColors.textSecondary),
                      ),
                    ),
                  ),
                  data: (_) => Stack(
                    children: [
                      KoruPullToRefresh(
                        // PERF: il drawer rinfresca SOLO l'inventario app (già
                        // auto-rinfrescato da PACKAGE_*/resume) invece di
                        // invalidare ~28 provider via il refresh globale.
                        refreshOverride: (ref) async {
                          ref.invalidate(installedAppsProvider);
                          ref.invalidate(installedPackageNamesProvider);
                          ref.invalidate(launcherPackagesProvider);
                          await Future<void>.delayed(
                            const Duration(milliseconds: 450),
                          );
                        },
                        child: AppListView(
                          scrollController: _scrollController,
                          phase: phase,
                        ),
                      ),
                      // Il rail salta alle sezioni A-Z, che durante la ricerca
                      // non esistono (la lista è piatta e ordinata per
                      // rilevanza): mostrarlo lì sarebbe un comando inerte.
                      if (!searching) ...[
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          child: FastScroller(
                            phase: phase,
                            availableLetters: grouped.keys.toSet(),
                            onLetterSelected: _onLetterSelected,
                            onScrubEnd: _onScrubEnd,
                          ),
                        ),
                        if (_scrubLetter != null)
                          _ScrubIndicator(
                            letter: _scrubLetter!,
                            phase: phase,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              AppSearchBar(
                phase: phase,
                matchCount: ref.watch(filteredAppsProvider).length,
                autofocus: widget.autofocusSearch,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Riga in cima al drawer: ora e inventario a sinistra, `Close` a destra.
/// Sostituisce l'AppBar — nessun titolo, nessuna freccia indietro.
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.phase, required this.totalApps});

  final LauncherPhase phase;
  final int totalApps;

  static final DateFormat _timeFormat = DateFormat.Hm();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            MinuteTickBuilder(
              builder: (context, now) => Text(
                '${_timeFormat.format(now)} · $totalApps apps',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: KoruColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              style: TextButton.styleFrom(foregroundColor: phase.accent),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

/// La lettera che il dito sta scorrendo sul rail, in un container tonale
/// accanto al righello. Non intercetta tocchi: è un indicatore, non un
/// controllo.
class _ScrubIndicator extends StatelessWidget {
  const _ScrubIndicator({required this.letter, required this.phase});

  final String letter;
  final LauncherPhase phase;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: AppListMetrics.railGutter + 8,
      top: 0,
      bottom: 0,
      child: Center(
        child: IgnorePointer(
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: phase.accentContainer,
              shape: const StadiumBorder(),
            ),
            child: Text(
              letter,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: phase.onAccentContainer,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
