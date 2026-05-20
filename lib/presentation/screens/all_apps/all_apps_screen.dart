import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_list_provider.dart';
import '../../widgets/koru_pull_to_refresh.dart';
import 'widgets/app_list_view.dart';
import 'widgets/app_search_bar.dart';
import 'widgets/fast_scroller.dart';

class AllAppsScreen extends ConsumerStatefulWidget {
  const AllAppsScreen({super.key});

  @override
  ConsumerState<AllAppsScreen> createState() => _AllAppsScreenState();
}

class _AllAppsScreenState extends ConsumerState<AllAppsScreen>
    with WidgetsBindingObserver {
  late final ScrollController _scrollController = ScrollController();
  final Map<String, double> _sectionOffsets = {};

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

  void _computeSectionOffsets(Map<String, dynamic> grouped) {
    _sectionOffsets.clear();
    // Le altezze base (50px tile / 40px header) sono quelle definite in
    // _AppTile e _SectionHeader. Se l'utente ha aumentato la font-scale di
    // sistema (Accessibility → Display size & text), le tile crescono e i
    // calcoli hard-coded portano il jump della fast-scrollbar ad ancorarsi
    // su offset sbagliati. Scaliamo via TextScaler così il jump resta
    // accurato anche per font scale 1.3x/1.5x.
    final textScaler = MediaQuery.textScalerOf(context);
    final tileHeight = textScaler.scale(50.0);
    final headerHeight = textScaler.scale(40.0);
    double offset = 4.0;
    for (final entry in grouped.entries) {
      _sectionOffsets[entry.key] = offset;
      offset += headerHeight;
      final list = entry.value as List;
      offset += list.length * tileHeight;
    }
  }

  void _onLetterSelected(String letter) {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('All apps'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const AppSearchBar(),
            Expanded(
              child: appsAsync.when(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text(
                    err.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                data: (_) => Stack(
                  children: [
                    KoruPullToRefresh(
                      child: AppListView(scrollController: _scrollController),
                    ),
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      child: FastScroller(
                        availableLetters: grouped.keys.toSet(),
                        onLetterSelected: _onLetterSelected,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
