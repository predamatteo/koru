import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/koru_colors.dart';
import '../../providers/mood_provider.dart';

/// Daily mood check-in sheet (1-5, optional note).
class MoodCheckInSheet extends ConsumerStatefulWidget {
  const MoodCheckInSheet({super.key});

  /// Show on the root navigator so the bottom sheet covers also the
  /// floating NavigationBar (otherwise the Save button sits underneath it).
  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (_) => const MoodCheckInSheet(),
      );

  @override
  ConsumerState<MoodCheckInSheet> createState() => _MoodCheckInSheetState();
}

class _MoodCheckInSheetState extends ConsumerState<MoodCheckInSheet> {
  int _mood = 3;
  final _note = TextEditingController();

  static const _emojis = ['😫', '😔', '😐', '🙂', '😊'];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(moodRepositoryProvider).upsertToday(
          mood: _mood,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
    ref.invalidate(todayMoodProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How do you feel today?',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          Row(
            children: List.generate(5, (i) {
              final selected = _mood == i + 1;
              return Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _mood = i + 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selected
                            ? KoruColors.primary.withValues(alpha: 0.25)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child:
                          Text(_emojis[i], style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
