import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/layout.dart';
import '../../providers/journal_provider.dart';

/// Schermata journaling: editor per la entry di oggi + lista cronologica
/// delle entry precedenti (ultimi 100 giorni). Una entry per giorno, upsert.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _controller = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    await ref.read(journalNotifierProvider).saveToday(text);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(todayJournalProvider);
    final allAsync = ref.watch(allJournalsProvider);

    // Primo hydration del controller dal DB (solo una volta).
    todayAsync.whenData((entry) {
      if (!_initialized && entry != null) {
        _controller.text = entry.body;
        _initialized = true;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, kBottomNavClearance),
        children: [
          Text(
            'Today · ${DateFormat('EEE, d MMM').format(DateTime.now())}',
            style: const TextStyle(
              color: KoruColors.textSecondary,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: KoruColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              maxLines: null,
              minLines: 6,
              decoration: const InputDecoration(
                hintText: 'What are you noticing today?',
                hintStyle: TextStyle(color: KoruColors.textSecondary),
                border: InputBorder.none,
              ),
              style: const TextStyle(height: 1.4),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'PAST ENTRIES',
            style: TextStyle(
              color: KoruColors.textSecondary,
              letterSpacing: 2,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          allAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('$e'),
            data: (entries) {
              final past = entries.skip(1).toList(); // exclude today, already shown in editor
              if (past.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No past entries yet. Come back tomorrow.',
                    style: TextStyle(color: KoruColors.textSecondary),
                  ),
                );
              }
              return Column(
                children: [
                  for (final e in past)
                    _PastEntryCard(
                      dayKey: e.dayStartDate,
                      body: e.body,
                      updatedAt: e.updatedAt,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PastEntryCard extends StatelessWidget {
  const _PastEntryCard({
    required this.dayKey,
    required this.body,
    required this.updatedAt,
  });

  final String dayKey;
  final String body;
  final int updatedAt;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(dayKey);
    final label = date == null
        ? dayKey
        : DateFormat('EEE, d MMM yyyy').format(date);
    return Card(
      color: KoruColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: KoruColors.textSecondary,
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(height: 1.4)),
          ],
        ),
      ),
    );
  }
}
