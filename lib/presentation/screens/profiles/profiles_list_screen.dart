import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../data/models/profile_model.dart';
import '../../providers/profile_providers.dart';

class ProfilesListScreen extends ConsumerWidget {
  const ProfilesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/profiles/new'),
        icon: const Icon(Icons.add),
        label: const Text('New profile'),
      ),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('$err')),
        data: (profiles) {
          if (profiles.isEmpty) return const _EmptyProfilesHint();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: profiles.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _ProfileTile(profile: profiles[i]),
          );
        },
      ),
    );
  }
}

class _ProfileTile extends ConsumerWidget {
  const _ProfileTile({required this.profile});

  final ProfileModel profile;

  Color get _badgeColor {
    final hex = profile.colorHex.replaceFirst('#', '');
    return Color(0xFF000000 | int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(profileRepositoryProvider);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _badgeColor.withValues(alpha: 0.2),
        foregroundColor: _badgeColor,
        child: Text(profile.emoji == 'NoIcon' ? '🌱' : profile.emoji),
      ),
      title: Text(profile.title.isEmpty ? 'Untitled' : profile.title),
      subtitle: Text(profile.subtitle,
          maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Switch(
        value: profile.isEnabled,
        onChanged: (v) => repo.toggleProfile(profile.id, v),
      ),
      onTap: () => context.push('/profiles/${profile.id}'),
    );
  }
}

class _EmptyProfilesHint extends StatelessWidget {
  const _EmptyProfilesHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined,
                size: 64, color: KoruColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No profiles yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a profile to define when and which apps to block.',
              textAlign: TextAlign.center,
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
