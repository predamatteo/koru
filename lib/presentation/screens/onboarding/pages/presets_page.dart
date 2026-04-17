import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../data/repositories/preset_repository.dart';
import '../../../providers/preset_provider.dart';

class PresetsPage extends ConsumerStatefulWidget {
  const PresetsPage({super.key});

  @override
  ConsumerState<PresetsPage> createState() => _PresetsPageState();
}

class _PresetsPageState extends ConsumerState<PresetsPage> {
  final _applied = <int>{};

  Future<void> _apply(KoruPreset preset) async {
    setState(() => _applied.add(preset.presetId));
    await ref.read(presetRepositoryProvider).apply(preset);
  }

  @override
  Widget build(BuildContext context) {
    final presetsAsync = ref.watch(allPresetsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: presetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (presets) => ListView(
          children: [
            Text('Quick start',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Tap a preset to create a ready-to-go profile. You can edit it later.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: KoruColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            for (final preset in presets)
              _PresetCard(
                preset: preset,
                applied: _applied.contains(preset.presetId),
                onApply: () => _apply(preset),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.applied,
    required this.onApply,
  });

  final KoruPreset preset;
  final bool applied;
  final VoidCallback onApply;

  Color get _bg {
    final hex = preset.colorHex.replaceFirst('#', '');
    return Color(0xFF000000 | int.parse(hex, radix: 16));
  }

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final iv = preset.intervals.first;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _bg.withValues(alpha: 0.2),
              foregroundColor: _bg,
              radius: 24,
              child: Text(preset.emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(preset.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatTime(iv.fromMinutes)} - ${_formatTime(iv.toMinutes)} · '
                    '${preset.blockedPackages.length} apps',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: KoruColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            applied
                ? const Icon(Icons.check_circle, color: KoruColors.success)
                : TextButton(onPressed: onApply, child: const Text('Apply')),
          ],
        ),
      ),
    );
  }
}
