import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/layout.dart';
import '../../../data/models/profile_model.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/model_labels.dart';
import '../../providers/profile_providers.dart';
import '../../widgets/koru_pull_to_refresh.dart';
import '../../widgets/unlock_challenge_dialog.dart';

class ProfilesListScreen extends ConsumerWidget {
  const ProfilesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabProfiles),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => context.push('/profiles/new'),
              icon: const Icon(Icons.add, size: 20),
              label: Text(l10n.profilesNew),
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

  /// Accendere un profilo è immediato; **spegnerlo** passa dalla sfida di
  /// sblocco (se configurata). L'asimmetria è voluta: l'attrito va messo solo
  /// nella direzione che indebolisce la protezione.
  Future<void> _onToggle(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (!enabled && profile.isEnabled) {
      final l10n = AppLocalizations.of(context);
      final granted = await requireUnlockChallenge(
        context,
        ref,
        action: l10n.profilesActionTurnOff(profile.displayTitleL10n(l10n)),
      );
      if (!granted) return;
    }
    await ref.read(profileRepositoryProvider).toggleProfile(profile.id, enabled);
  }

  String _buildSubtitle(AppLocalizations l10n) {
    final parts = <String>[profile.dayFlagsLabel(l10n)];
    if (profile.hasTimeCondition && profile.intervals.isNotEmpty) {
      parts.add(
        profile.intervals
            // from == to e' la fascia 24h, non una finestra a lunghezza zero.
            .map((iv) => iv.fromMinutes == iv.toMinutes
                ? l10n.profilesAllDay
                : '${_fmt(iv.fromMinutes)}\u2013${_fmt(iv.toMinutes)}')
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
    final appsCount = profile.apps.length;
    final l10n = AppLocalizations.of(context);
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
                        profile.displayTitleL10n(l10n),
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
                      onChanged: (v) => _onToggle(context, ref, v),
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
                    _buildSubtitle(l10n),
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
                        l10n.profilesAppsBlocked(appsCount).toUpperCase(),
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
                      child: Text(
                        l10n.commonEdit,
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
              AppLocalizations.of(context).profilesEmptyTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).profilesEmptyBody,
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
