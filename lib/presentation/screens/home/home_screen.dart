import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/layout.dart';
import '../../../core/diagnostics/black_box.dart';
import '../../../data/models/profile_model.dart';
import '../../providers/active_profile_provider.dart';
import '../../providers/app_list_provider.dart';
import '../../providers/events_refresher.dart';
import '../../providers/profile_providers.dart';
import '../../providers/statistics_providers.dart';
import '../../widgets/koru_pull_to_refresh.dart';
import 'widgets/accessibility_health_banner.dart';
import 'widgets/today_limits_card.dart';

/// Tab Home dell'app: dashboard con greeting, profilo attivo ora, quick stats,
/// shortcuts a Focus/Profiles/All apps.
///
/// Questa NON è la home del launcher (clock+favoriti) — quella vive a
/// `/launcher` ed è visibile solo quando Koru è lanciato come default launcher.
///
/// One-shot per processo: primo frame renderizzato della dashboard (vero
/// "time-to-usable" quando Koru NON è il launcher di default).
bool _homeFirstFrameLogged = false;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_homeFirstFrameLogged) {
      _homeFirstFrameLogged = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => BlackBox.log('DART', 'Home dashboard primo frame renderizzato'),
      );
    }
    final allProfiles = ref.watch(profilesProvider).valueOrNull ?? [];
    final activeProfiles = ref.watch(activeProfilesProvider).valueOrNull ?? [];
    final blocksToday = ref.watch(blockTriggeredCountProvider).valueOrNull ?? 0;
    final focusMs = ref.watch(focusTimeMsProvider).valueOrNull ?? 0;

    // Pre-warm della lista app così quando l'utente entra in
    // "Select apps" dentro un profilo la risposta native è già cached.
    ref.watch(installedAppsProvider);

    // Ascolta gli eventi native di blocking → invalida i count in real-time.
    ref.watch(blockingEventsRefresherProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Koru')),
      body: KoruPullToRefresh(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, kBottomNavClearance),
          children: [
            const AccessibilityHealthBanner(),
            const _GreetingCard(),
            const SizedBox(height: 12),
            _ActiveProfileCard(
              totalProfiles: allProfiles.length,
              activeProfiles: activeProfiles,
            ),
            const SizedBox(height: 12),
            _TodayStatsRow(blocksToday: blocksToday, focusMs: focusMs),
            const SizedBox(height: 12),
            const TodayLimitsCard(),
            const SizedBox(height: 12),
            const _QuickActionsCard(),
          ],
        ),
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
    return Container(
      decoration: BoxDecoration(
        color: KoruColors.surface,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greeting(),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1.05,
              color: KoruColors.textPrimary,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Take a breath. What do you want to focus on today?',
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: KoruColors.textSecondary,
            ),
          ),
        ],
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
      title =
          '$totalProfiles ${totalProfiles == 1 ? 'profile' : 'profiles'} configured';
    } else {
      eyebrow = 'No profiles yet';
      title = 'Create one to get started';
    }

    final primaryActive = activeProfiles.isNotEmpty
        ? activeProfiles.first
        : null;

    // Tonal primary-container card in every state (M3 Expressive): the active
    // profile is the dashboard's most prominent surface. Content is the dark-on
    // color for the bright primary container.
    const onc = KoruColors.onPrimaryContainer;
    return Container(
      decoration: BoxDecoration(
        color: KoruColors.primaryContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => GoRouter.of(context).go('/profiles'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: hasActive
                    ? Text(
                        primaryActive!.emoji == 'NoIcon'
                            ? '🌱'
                            : primaryActive.emoji,
                        style: const TextStyle(fontSize: 22),
                      )
                    : Icon(
                        hasAny ? Icons.shield : Icons.add_circle_outline,
                        color: onc,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: onc,
                      ).copyWith(color: onc.withValues(alpha: 0.72)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: onc,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: onc),
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
            icon: Icons.shield,
            iconColor: KoruColors.primary,
            label: 'Blocks',
            value: '$blocksToday',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniStat(
            icon: Icons.self_improvement,
            iconColor: KoruColors.tertiary,
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
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KoruColors.surfaceContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: iconColor),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 33,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1,
              color: KoruColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: KoruColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 2, 4, 9),
          child: Text(
            'QUICK ACTIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: KoruColors.textSecondary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: KoruColors.surface,
            borderRadius: BorderRadius.circular(26),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _QuickActionRow(
                icon: Icons.timer_outlined,
                label: 'Quick block',
                onTap: () => GoRouter.of(context).go('/focus/quick'),
              ),
              const _QuickActionDivider(),
              _QuickActionRow(
                icon: Icons.hourglass_top,
                label: 'Pomodoro',
                onTap: () => GoRouter.of(context).go('/focus/pomodoro'),
              ),
              const _QuickActionDivider(),
              _QuickActionRow(
                icon: Icons.shield_outlined,
                label: 'Manage profiles',
                onTap: () => GoRouter.of(context).go('/profiles'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionDivider extends StatelessWidget {
  const _QuickActionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      color: KoruColors.outline,
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 22, color: KoruColors.primary),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: KoruColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: KoruColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
