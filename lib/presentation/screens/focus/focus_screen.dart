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

/// Landing screen del Focus tab: editorial heading mindful + card Quick
/// Block con chip preset (tap = start immediato) + card Pomodoro con
/// play button. Tap sul corpo delle card naviga al detail per customizzare.
class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickAsync = ref.watch(quickBlockTickProvider);
    final isActive = tickAsync.valueOrNull?.isActive ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: KoruPullToRefresh(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, kBottomNavClearance),
          children: [
            if (isActive) ...[
              _ActiveBanner(tick: tickAsync.valueOrNull!),
              const SizedBox(height: 24),
            ] else ...[
              const _Heading(),
              const SizedBox(height: 24),
            ],
            const _QuickBlockCard(),
            const SizedBox(height: 16),
            const _PomodoroCard(),
          ],
        ),
      ),
    );
  }
}

/// Heading mindful che cambia con il momento della giornata — dà un senso
/// di intenzione alla landing del focus.
class _Heading extends StatelessWidget {
  const _Heading();

  ({String title, String subtitle}) _copy() {
    final h = DateTime.now().hour;
    if (h < 5) return (title: 'Late hours.', subtitle: 'Be kind to the mind.');
    if (h < 12) {
      return (title: 'A quiet morning.', subtitle: 'Choose one thing.');
    }
    if (h < 18) {
      return (
        title: 'A single hour.',
        subtitle: 'Close the door on everything else.',
      );
    }
    return (title: 'Evening focus.', subtitle: 'Wind down, not scroll down.');
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: KoruColors.textPrimary,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            c.subtitle,
            style: const TextStyle(
              color: KoruColors.textSecondary,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card Quick Block: section label + copy editorial + chip preset row.
/// Tap su chip → start immediato. Tap sul corpo (non-chip) → detail screen.
class _QuickBlockCard extends ConsumerWidget {
  const _QuickBlockCard();

  static const _presets = [15, 30, 60, 120];

  Future<void> _start(WidgetRef ref, int minutes) async {
    final blocking = ref.read(platformChannelServiceProvider).blocking;
    final whitelist = ref.read(focusWhitelistProvider(FocusMode.quickBlock));
    await ref
        .read(hiveSettingsServiceProvider)
        .put(
          HiveKeys.quickTogglesBox,
          HiveKeys.lastQuickBlockDurationMinutes,
          minutes,
        );
    await blocking.startQuickBlock(
      Duration(minutes: minutes),
      whitelist: whitelist.toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hive = ref.watch(hiveSettingsServiceProvider);
    final last = hive.getInt(
      HiveKeys.quickTogglesBox,
      HiveKeys.lastQuickBlockDurationMinutes,
      defaultValue: 30,
    );

    return _Card(
      onTap: () => context.push('/focus/quick'),
      trailing: _EditButton(onTap: () => context.push('/focus/quick')),
      children: [
        const _SectionLabel('Quick block'),
        const SizedBox(height: 10),
        Text(
          'One tap. Phone quiet.',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: KoruColors.textPrimary,
            fontWeight: FontWeight.w500,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            for (final p in _presets) ...[
              Expanded(
                child: _PresetChip(
                  label: _formatPreset(p),
                  selected: p == last,
                  onTap: () => _start(ref, p),
                ),
              ),
              if (p != _presets.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  static String _formatPreset(int minutes) {
    if (minutes < 60) return '${minutes}m';
    if (minutes % 60 == 0) return '${minutes ~/ 60}h';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }
}

/// Card Pomodoro: section label + copy editorial + metadata + play button.
class _PomodoroCard extends ConsumerWidget {
  const _PomodoroCard();

  Future<void> _start(
    WidgetRef ref,
    int workMin,
    int breakMin,
    int cycles,
  ) async {
    final blocking = ref.read(platformChannelServiceProvider).blocking;
    final whitelist = ref.read(focusWhitelistProvider(FocusMode.pomodoro));
    await blocking.startPomodoro(
      workPhase: Duration(minutes: workMin),
      breakPhase: Duration(minutes: breakMin),
      cycles: cycles,
      whitelist: whitelist.toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hive = ref.watch(hiveSettingsServiceProvider);
    final work = hive.getInt(
      HiveKeys.quickTogglesBox,
      HiveKeys.lastPomodoroWorkMinutes,
      defaultValue: 25,
    );
    final brk = hive.getInt(
      HiveKeys.quickTogglesBox,
      HiveKeys.lastPomodoroBreakMinutes,
      defaultValue: 5,
    );
    final cycles = hive.getInt(
      HiveKeys.quickTogglesBox,
      HiveKeys.lastPomodoroCycles,
      defaultValue: 4,
    );
    final totalMinutes = (work + brk) * cycles;
    final totalHours = totalMinutes / 60;

    return _Card(
      onTap: () => context.push('/focus/pomodoro'),
      trailing: _EditButton(onTap: () => context.push('/focus/pomodoro')),
      children: [
        const _SectionLabel('Pomodoro'),
        const SizedBox(height: 10),
        Text(
          '$work on, $brk off.\nRepeat until done.',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: KoruColors.textPrimary,
            fontWeight: FontWeight.w500,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                '$cycles cycles · ${_formatTotal(totalHours, totalMinutes)}',
                style: const TextStyle(
                  color: KoruColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            _PlayButton(onTap: () => _start(ref, work, brk, cycles)),
          ],
        ),
      ],
    );
  }

  static String _formatTotal(double hours, int minutes) {
    if (hours >= 1) {
      final whole = hours.floor();
      final frac = (hours - whole);
      if (frac < 0.05) return '${whole}h total';
      return '${hours.toStringAsFixed(1)}h total';
    }
    return '${minutes}m total';
  }
}

// ─── Shared primitives ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.children, required this.onTap, this.trailing});
  final List<Widget> children;
  final VoidCallback onTap;

  /// Widget overlay top-right (es. edit gear / close button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KoruColors.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
          if (trailing != null) Positioned(top: 8, right: 8, child: trailing!),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.tune,
            size: 18,
            color: KoruColors.textSecondary.withAlpha(200),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KoruColors.danger.withAlpha(40),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.close, size: 18, color: KoruColors.danger),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: KoruColors.primary.withAlpha(220),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
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
      color: selected
          ? KoruColors.primary.withAlpha(40)
          : KoruColors.surfaceElevated,
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? KoruColors.primary : KoruColors.textPrimary,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KoruColors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.play_arrow, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

// ─── Active banner (while a session is running) ─────────────────────────────

class _ActiveBanner extends ConsumerWidget {
  const _ActiveBanner({required this.tick});
  final dynamic tick;

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Future<void> _stop(WidgetRef ref) async {
    final blocking = ref.read(platformChannelServiceProvider).blocking;
    // Una sola chiamata gestisce sia quick block che pomodoro: il
    // QuickBlockManager nativo lavora sullo stesso state machine.
    await blocking.stopQuickBlock();
    await blocking.stopPomodoro();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remainingMs = tick.remainingMs as int;
    final totalMs = tick.totalMs as int;
    final phase = tick.isPomodoroBreak as bool ? 'Break' : 'Focus';
    final progress = totalMs == 0 ? 0.0 : 1 - (remainingMs / totalMs);
    return _Card(
      onTap: () {},
      trailing: _CloseButton(onTap: () => _stop(ref)),
      children: [
        _SectionLabel(phase),
        const SizedBox(height: 10),
        Text(
          _fmt(remainingMs),
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: KoruColors.textPrimary,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1).toDouble(),
            minHeight: 5,
            backgroundColor: KoruColors.surfaceElevated,
            valueColor: const AlwaysStoppedAnimation<Color>(KoruColors.primary),
          ),
        ),
      ],
    );
  }
}
