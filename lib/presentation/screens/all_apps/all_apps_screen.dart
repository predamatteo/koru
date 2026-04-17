import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_list_provider.dart';
import 'widgets/app_list_view.dart';
import 'widgets/app_search_bar.dart';
import 'widgets/fast_scroller.dart';

class AllAppsScreen extends ConsumerStatefulWidget {
  const AllAppsScreen({super.key});

  @override
  ConsumerState<AllAppsScreen> createState() => _AllAppsScreenState();
}

class _AllAppsScreenState extends ConsumerState<AllAppsScreen> {
  late final ScrollController _scrollController = ScrollController();
  final Map<String, double> _sectionOffsets = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _computeSectionOffsets(Map<String, dynamic> grouped) {
    _sectionOffsets.clear();
    const headerHeight = 40.0;
    const tileHeight = 50.0;
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
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text(
                    err.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                data: (_) => Stack(
                  children: [
                    AppListView(scrollController: _scrollController),
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
