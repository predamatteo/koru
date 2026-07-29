import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/koru_type.dart';
import '../../../core/theme/launcher_phase.dart';
import '../../../platform/blocking_channel.dart';
import '../../providers/app_list_provider.dart';
import '../../widgets/koru_pull_to_refresh.dart';
import '../../widgets/minute_tick_builder.dart';
import 'widgets/app_list_view.dart';
import 'widgets/app_search_bar.dart';
import 'widgets/fast_scroller.dart';

/// Il drawer "tutte le app" — la seconda metà di "Inchiostro e ore".
///
/// Cosa cambia rispetto alla schermata di prima, e perché:
///
/// - **niente AppBar.** Era il capo di una pagina di impostazioni prestato a
///   un launcher. Al suo posto una riga meta in mono: ora, quante app, e la
///   parola `CLOSE`.
/// - **la query sta in basso**, sopra la tastiera ([AppSearchBar]), e la lista
///   è ancorata al fondo: i risultati crescono verso il pollice.
/// - **la lettera fantasma**: mentre il dito scorre il rail A-Z, la lettera
///   appare in serif da 240px dietro la lista. Il feedback è grande, il
///   righello resta piccolo.
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

  /// Lettera mostrata in gigante dietro la lista mentre si scorre il rail.
  String? _ghostLetter;
  Timer? _ghostTimer;

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
    _ghostTimer?.cancel();
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
    final headerHeight = AppListMetrics.headerHeight(textScaler);
    final tileHeight = AppListMetrics.rowHeight(
      textScaler,
      AppListMetrics.browseFontSize,
    );
    var offset = AppListMetrics.topPadding;
    for (final entry in grouped.entries) {
      _sectionOffsets[entry.key] = offset;
      offset += headerHeight + entry.value.length * tileHeight;
    }
  }

  void _onLetterSelected(String letter) {
    _ghostTimer?.cancel();
    if (_ghostLetter != letter) setState(() => _ghostLetter = letter);

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
    _ghostTimer?.cancel();
    _ghostTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _ghostLetter = null);
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
                        style: KoruType.serif(
                          size: 20,
                          height: 1.3,
                          color: phase.ink2,
                        ),
                      ),
                    ),
                  ),
                  data: (_) => Stack(
                    children: [
                      if (_ghostLetter != null)
                        _GhostLetter(letter: _ghostLetter!, phase: phase),
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
                      if (!searching)
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

/// Riga meta in cima al drawer: ora e inventario a sinistra, `CLOSE` a destra.
/// Sostituisce l'AppBar — nessun titolo, nessuna freccia indietro.
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.phase, required this.totalApps});

  final LauncherPhase phase;
  final int totalApps;

  static final DateFormat _timeFormat = DateFormat.Hm();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            MinuteTickBuilder(
              builder: (context, now) => Text(
                '${_timeFormat.format(now)} · $totalApps APPS',
                style: KoruType.mono(
                  size: 10,
                  color: phase.ink2,
                  trackEm: phase.trackEm,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
                child: Text(
                  'CLOSE',
                  style: KoruType.mono(
                    size: 10,
                    color: phase.accent,
                    trackEm: phase.trackEm,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La lettera che il dito sta scorrendo sul rail, in serif da 240px dietro la
/// lista. Non intercetta tocchi: è un segno d'acqua, non un controllo.
class _GhostLetter extends StatelessWidget {
  const _GhostLetter({required this.letter, required this.phase});

  final String letter;
  final LauncherPhase phase;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 26,
      bottom: 0,
      child: IgnorePointer(
        child: Text(
          letter,
          style: KoruType.serif(
            size: 240,
            height: 0.7,
            color: phase.ink,
            opacity: 0.13,
          ),
        ),
      ),
    );
  }
}
