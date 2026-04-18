import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/day_flags.dart';
import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/profile_types.dart';
import '../../providers/achievements_provider.dart';
import '../../providers/profile_providers.dart';

class ProfileEditorScreen extends ConsumerStatefulWidget {
  const ProfileEditorScreen({super.key, this.profileId});

  final int? profileId;

  bool get isNew => profileId == null;

  @override
  ConsumerState<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

/// Set minimo di emoji adatte a profili (work, focus, mindfulness, sleep,
/// break). Tutte emoji single-codepoint per evitare problemi di fallback.
const List<String> _emojiPalette = [
  '🌿', '🌅', '🌙', '🧠', '💼', '🎯',
  '📚', '🏃', '🧘', '🛌', '☕', '🔕',
];

class _ProfileEditorScreenState extends ConsumerState<ProfileEditorScreen> {
  final _titleController = TextEditingController();
  String _emoji = '🌿';
  int _dayFlags = DayFlags.allDays;
  int _blockingMode = BlockingMode.blocklist;
  int _typeCombinations = ProfileType.time;
  TimeOfDay _from = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 17, minute: 0);
  bool _timeEnabled = true;
  bool _loaded = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting(int id) async {
    if (_loaded) return;
    final profile = await ref.read(profileByIdProvider(id).future);
    if (profile == null || !mounted) return;
    setState(() {
      _loaded = true;
      _titleController.text = profile.title;
      _emoji = profile.emoji == 'NoIcon' ? '🌿' : profile.emoji;
      _dayFlags = profile.dayFlags;
      _blockingMode = profile.blockingMode;
      _typeCombinations = profile.typeCombinations;
      _timeEnabled = ProfileType.hasType(_typeCombinations, ProfileType.time);
      if (profile.intervals.isNotEmpty) {
        final iv = profile.intervals.first;
        _from = TimeOfDay(hour: iv.fromMinutes ~/ 60, minute: iv.fromMinutes % 60);
        _to = TimeOfDay(hour: iv.toMinutes ~/ 60, minute: iv.toMinutes % 60);
      }
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name the profile first')),
      );
      return;
    }
    final repo = ref.read(profileRepositoryProvider);
    final typeCombinations = _timeEnabled
        ? ProfileType.addType(_typeCombinations, ProfileType.time)
        : ProfileType.removeType(_typeCombinations, ProfileType.time);

    int profileId;
    if (widget.isNew) {
      profileId = await repo.createProfile(
        title: title,
        emoji: _emoji,
        dayFlags: _dayFlags,
        blockingMode: _blockingMode,
        typeCombinations: typeCombinations,
      );
    } else {
      profileId = widget.profileId!;
      await repo.updateProfileDetails(
        id: profileId,
        title: title,
        emoji: _emoji,
        dayFlags: _dayFlags,
        blockingMode: _blockingMode,
        typeCombinations: typeCombinations,
      );
    }

    if (_timeEnabled) {
      await repo.setIntervalsForProfile(profileId, [
        (from: _from.hour * 60 + _from.minute, to: _to.hour * 60 + _to.minute),
      ]);
    } else {
      await repo.setIntervalsForProfile(profileId, const []);
    }

    await ref.read(achievementEvaluationProvider.notifier).trigger();
    if (mounted) context.pop();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _from : _to,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _from = picked;
        } else {
          _to = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isNew && !_loaded) {
      _loadExisting(widget.profileId!);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New profile' : 'Edit profile'),
        actions: [
          if (!widget.isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: KoruColors.danger),
              onPressed: () async {
                await ref
                    .read(profileRepositoryProvider)
                    .deleteProfile(widget.profileId!);
                if (context.mounted) context.pop();
              },
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Profile name',
              hintText: 'e.g. Deep Work',
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Icon'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _emojiPalette.map((emoji) {
              final selected = _emoji == emoji;
              return InkWell(
                onTap: () => setState(() => _emoji = emoji),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? KoruColors.primary.withValues(alpha: 0.22)
                        : KoruColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? KoruColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Days'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: DayFlags.ordered.map((day) {
              final selected = DayFlags.hasDay(_dayFlags, day);
              return FilterChip(
                label: Text(DayFlags.shortLabels[day]!),
                selected: selected,
                onSelected: (_) => setState(
                    () => _dayFlags = DayFlags.toggleDay(_dayFlags, day)),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            value: _timeEnabled,
            onChanged: (v) => setState(() => _timeEnabled = v),
            title: const Text('Time window'),
            subtitle: const Text('Activate the profile only within a time range'),
            contentPadding: EdgeInsets.zero,
          ),
          if (_timeEnabled) ...[
            Row(
              children: [
                Expanded(
                  child: _TimeTile(label: 'From', time: _from, onTap: () => _pickTime(true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeTile(label: 'To', time: _to, onTap: () => _pickTime(false)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          _SectionHeader(title: 'Blocking mode'),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: BlockingMode.blocklist, label: Text('Blocklist')),
              ButtonSegment(value: BlockingMode.allowlist, label: Text('Allowlist')),
            ],
            selected: {_blockingMode},
            onSelectionChanged: (s) => setState(() => _blockingMode = s.first),
          ),
          if (!widget.isNew) ...[
            const SizedBox(height: 24),
            _SectionHeader(title: 'What to block'),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.apps_outlined),
              title: const Text('Blocked apps'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profiles/${widget.profileId}/apps'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.layers_clear_outlined),
              title: const Text('In-app content'),
              subtitle: const Text(
                  'Instagram Reels/Stories/Explore · YouTube Shorts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profiles/${widget.profileId}/sections'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language_outlined),
              title: const Text('Websites'),
              subtitle: const Text(
                  'Block domains inside browsers (Chrome, Firefox, Brave…)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profiles/${widget.profileId}/websites'),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              'Save the profile first, then configure apps and in-app sections.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KoruColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: KoruColors.textSecondary,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
      );
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.label, required this.time, required this.onTap});

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: KoruColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: KoruColors.textSecondary,
                    letterSpacing: 1,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              formatted,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}
