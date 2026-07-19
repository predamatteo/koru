import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/hive_keys.dart';
import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/layout.dart';
import '../../../core/di/providers.dart';
import '../../providers/focus_session_provider.dart';
import '../../providers/focus_whitelist_provider.dart';
import '../../widgets/koru_pull_to_refresh.dart';

class QuickBlockScreen extends ConsumerStatefulWidget {
  const QuickBlockScreen({super.key});

  @override
  ConsumerState<QuickBlockScreen> createState() => _QuickBlockScreenState();
}

class _QuickBlockScreenState extends ConsumerState<QuickBlockScreen> {
  static const _presets = <int>[15, 30, 60, 120];
  int _minutes = 30;

  @override
  void initState() {
    super.initState();
    final hive = ref.read(hiveSettingsServiceProvider);
    _minutes = hive.getInt(
      HiveKeys.quickTogglesBox,
      HiveKeys.lastQuickBlockDurationMinutes,
      defaultValue: 30,
    );
  }

  Future<void> _start() async {
    final blocking = ref.read(platformChannelServiceProvider).blocking;
    final whitelist = ref.read(focusWhitelistProvider(FocusMode.quickBlock));
    await ref
        .read(hiveSettingsServiceProvider)
        .put(
          HiveKeys.quickTogglesBox,
          HiveKeys.lastQuickBlockDurationMinutes,
          _minutes,
        );
    await blocking.startQuickBlock(
      Duration(minutes: _minutes),
      whitelist: whitelist.toList(growable: false),
    );
    if (mounted) context.pop();
  }

  Future<void> _stop() async {
    final blocking = ref.read(platformChannelServiceProvider).blocking;
    await blocking.stopQuickBlock();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tick = ref.watch(quickBlockTickProvider).valueOrNull;
    final isActive = tick?.isActive ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick block'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: KoruPullToRefresh(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, kBottomNavClearance),
          children: [
            if (isActive)
              _ActiveCard(tick: tick!, onStop: _stop)
            else ...[
              const _SectionLabel('Duration'),
              const SizedBox(height: 10),
              _DurationStepper(
                value: _minutes,
                min: 5,
                max: 240,
                step: 5,
                onChanged: (v) => setState(() => _minutes = v),
              ),
              const SizedBox(height: 14),
              _PresetRow(
                presets: _presets,
                selected: _minutes,
                onTap: (v) => setState(() => _minutes = v),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Whitelist'),
              const SizedBox(height: 10),
              _WhitelistCard(
                onTap: () => context.push('/focus/quick/whitelist'),
              ),
              const SizedBox(height: 32),
              _StartButton(
                label: 'Start ${_formatDuration(_minutes)}',
                onTap: _start,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDuration(int minutes) {
  if (minutes < 60) return '${minutes}m';
  if (minutes % 60 == 0) return '${minutes ~/ 60}h';
  return '${minutes ~/ 60}h ${minutes % 60}m';
}

// ─── Active card (durante la sessione) ──────────────────────────────────────

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.tick, required this.onStop});
  final dynamic tick;
  final VoidCallback onStop;

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final remainingMs = tick.remainingMs as int;
    final totalMs = tick.totalMs as int;
    final progress = totalMs == 0 ? 0.0 : 1 - (remainingMs / totalMs);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _SectionLabel('In progress', center: true),
          const SizedBox(height: 14),
          Text(
            _fmt(remainingMs),
            style: const TextStyle(
              color: KoruColors.textPrimary,
              fontSize: 64,
              fontWeight: FontWeight.w300,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1).toDouble(),
              minHeight: 5,
              backgroundColor: KoruColors.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(
                KoruColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
              style: FilledButton.styleFrom(
                backgroundColor: KoruColors.danger,
                foregroundColor: KoruColors.onDanger,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Duration stepper custom ────────────────────────────────────────────────

class _DurationStepper extends StatelessWidget {
  const _DurationStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          _StepperButton(
            icon: Icons.remove,
            enabled: value > min,
            onTap: () => onChanged((value - step).clamp(min, max).toInt()),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: KoruColors.textPrimary,
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'minutes',
                  style: TextStyle(
                    color: KoruColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            enabled: value < max,
            onTap: () => onChanged((value + step).clamp(min, max).toInt()),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? KoruColors.primary.withAlpha(40)
          : KoruColors.surfaceElevated,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: enabled
                ? KoruColors.primary
                : KoruColors.textSecondary.withAlpha(120),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.presets,
    required this.selected,
    required this.onTap,
  });
  final List<int> presets;
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final p in presets) ...[
          Expanded(
            child: _PresetChip(
              label: _formatDuration(p),
              selected: p == selected,
              onTap: () => onTap(p),
            ),
          ),
          if (p != presets.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? KoruColors.primary.withAlpha(40) : KoruColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? KoruColors.primary : Colors.transparent,
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? KoruColors.primary : KoruColors.textPrimary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _WhitelistCard extends StatelessWidget {
  const _WhitelistCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(
            Icons.playlist_add_check,
            color: KoruColors.primary,
            size: 22,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allowed apps',
                  style: TextStyle(
                    color: KoruColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Stay usable during the session',
                  style: TextStyle(
                    color: KoruColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: KoruColors.textSecondary.withAlpha(140),
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.play_arrow),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        style: FilledButton.styleFrom(
          backgroundColor: KoruColors.primary,
          foregroundColor: KoruColors.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final container = Container(
      decoration: BoxDecoration(
        color: KoruColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
    if (onTap == null) return container;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: container,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.center = false});
  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        text.toUpperCase(),
        textAlign: center ? TextAlign.center : TextAlign.start,
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
