import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/layout.dart';
import '../../../data/models/profile_model.dart';
import '../../providers/profile_providers.dart';
import '../../widgets/koru_pull_to_refresh.dart';

class ProfilesListScreen extends ConsumerWidget {
  const ProfilesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles'),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => context.push('/profiles/new'),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('New'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(0, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      body: KoruPullToRefresh(
        child: profilesAsync.when(
          loading: () => const KoruRefreshableViewport(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) =>
              KoruRefreshableViewport(child: Center(child: Text('$err'))),
          data: (profiles) {
            if (profiles.isEmpty) {
              return const KoruRefreshableViewport(child: _EmptyProfilesHint());
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                kBottomNavClearance,
              ),
              itemCount: profiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _ProfileCard(profile: profiles[i]),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.profile});
  final ProfileModel profile;

  String _buildSubtitle() {
    final parts = <String>[profile.dayFlagsLabel];
    if (profile.hasTimeCondition && profile.intervals.isNotEmpty) {
      parts.add(
        profile.intervals
            .map((iv) => '${_fmt(iv.fromMinutes)}\u2013${_fmt(iv.toMinutes)}')
            .join(', '),
      );
    }
    return parts.join(' \u00b7 ');
  }

  static String _fmt(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(profileRepositoryProvider);
    final appsCount = profile.apps.length;
    return Container(
      decoration: BoxDecoration(
        color: KoruColors.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/profiles/${profile.id}'),
          child: Column(
            children: [
              // Top: emoji + title + switch
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _EmojiBadge(emoji: profile.emoji),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        profile.title.isEmpty ? 'Untitled' : profile.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: KoruColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch(
                      value: profile.isEnabled,
                      onChanged: (v) => repo.toggleProfile(profile.id, v),
                    ),
                  ],
                ),
              ),
              // Subtitle
              Padding(
                padding: const EdgeInsets.fromLTRB(60, 0, 20, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _buildSubtitle(),
                    style: const TextStyle(
                      color: KoruColors.textSecondary,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
              // Divider
              Container(height: 1, color: KoruColors.surfaceElevated),
              // Footer: apps count + Edit
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$appsCount APPS BLOCKED',
                        style: TextStyle(
                          color: KoruColors.textSecondary.withAlpha(200),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: KoruColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => context.push('/profiles/${profile.id}'),
                      child: const Text(
                        'Edit',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmojiBadge extends StatelessWidget {
  const _EmojiBadge({required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: KoruColors.primary.withAlpha(40),
        shape: BoxShape.circle,
      ),
      child: Text(
        emoji == 'NoIcon' ? '🌿' : emoji,
        style: const TextStyle(fontSize: 18),
      ),
    );
  }
}

class _EmptyProfilesHint extends StatelessWidget {
  const _EmptyProfilesHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, kBottomNavClearance),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 64,
              color: KoruColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No profiles yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to create your first profile and pick when and which '
              'apps to block.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: KoruColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
