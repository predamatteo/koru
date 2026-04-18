import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/layout.dart';
import '../../../data/models/profile_model.dart';
import '../../providers/active_profile_provider.dart';
import '../../providers/app_list_provider.dart';
import '../../providers/profile_providers.dart';
import '../../providers/statistics_providers.dart';

/// Tab Home dell'app: dashboard con greeting, profilo attivo ora, quick stats,
/// shortcuts a Focus/Profiles/All apps.
///
/// Questa NON è la home del launcher (clock+favoriti) — quella vive a
/// `/launcher` ed è visibile solo quando Koru è lanciato come default launcher.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allProfiles = ref.watch(profilesProvider).valueOrNull ?? [];
    final activeProfiles = ref.watch(activeProfilesProvider).valueOrNull ?? [];
    final blocksToday = ref.watch(blockTriggeredCountProvider).valueOrNull ?? 0;
    final focusMs = ref.watch(focusTimeMsProvider).valueOrNull ?? 0;

    // Pre-warm della lista app così quando l'utente entra in
    // "Select apps" dentro un profilo la risposta native è già cached.
    ref.watch(installedAppsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Koru')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, kBottomNavClearance),
        children: [
          const _GreetingCard(),
          const SizedBox(height: 12),
          _ActiveProfileCard(
            totalProfiles: allProfiles.length,
            activeProfiles: activeProfiles,
          ),
          const SizedBox(height: 12),
          _TodayStatsRow(blocksToday: blocksToday, focusMs: focusMs),
          const SizedBox(height: 12),
          const _QuickActionsCard(),
        ],
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard();

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Still awake?';
    if (h < 12) return 'Good morning.';
    if (h < 18) return 'Good afternoon.';
    return 'Good evening.';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: KoruColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Take a breath. What do you want to focus on today?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: KoruColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveProfileCard extends StatelessWidget {
  const _ActiveProfileCard({
    required this.totalProfiles,
    required this.activeProfiles,
  });

  final int totalProfiles;
  final List<ProfileModel> activeProfiles;

  @override
  Widget build(BuildContext context) {
    final hasActive = activeProfiles.isNotEmpty;
    final hasAny = totalProfiles > 0;

    final String eyebrow;
    final String title;
    if (hasActive) {
      eyebrow = 'Active right now';
      title = activeProfiles.map((p) => p.title).join(' · ');
    } else if (hasAny) {
      eyebrow = 'No profile active now';
      title = '$totalProfiles ${totalProfiles == 1 ? 'profile' : 'profiles'} configured';
    } else {
      eyebrow = 'No profiles yet';
      title = 'Create one to get started';
    }

    return Card(
      color: hasActive ? KoruColors.primaryContainer : KoruColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => GoRouter.of(context).go('/profiles'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                hasActive
                    ? Icons.shield
                    : (hasAny ? Icons.shield_outlined : Icons.add_circle_outline),
                color:
                    hasActive ? KoruColors.primary : KoruColors.textSecondary,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: KoruColors.textSecondary,
                            letterSpacing: 2,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: KoruColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayStatsRow extends StatelessWidget {
  const _TodayStatsRow({required this.blocksToday, required this.focusMs});

  final int blocksToday;
  final int focusMs;

  String _fmtMs(int ms) {
    final s = ms ~/ 1000;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            icon: Icons.shield_outlined,
            label: 'Blocks',
            value: '$blocksToday',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniStat(
            icon: Icons.self_improvement_outlined,
            label: 'Focus',
            value: _fmtMs(focusMs),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: KoruColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: KoruColors.textSecondary),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KoruColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsCard extends ConsumerWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: KoruColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                'Quick actions',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: KoruColors.textSecondary,
                      letterSpacing: 2,
                    ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined,
                  color: KoruColors.primary),
              title: const Text('Quick block'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => GoRouter.of(context).go('/focus/quick'),
            ),
            ListTile(
              leading: const Icon(Icons.hourglass_bottom_outlined,
                  color: KoruColors.primary),
              title: const Text('Pomodoro'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => GoRouter.of(context).go('/focus/pomodoro'),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined,
                  color: KoruColors.primary),
              title: const Text('Manage profiles'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => GoRouter.of(context).go('/profiles'),
            ),
          ],
        ),
      ),
    );
  }
}
