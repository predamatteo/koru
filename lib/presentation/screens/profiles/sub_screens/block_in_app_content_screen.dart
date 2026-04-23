import 'package:collection/collection.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/models/profile_model.dart';
import '../../../../domain/entities/blocked_section.dart';
import '../../../providers/profile_providers.dart';

/// Configure le sezioni in-app bloccate (Instagram Reels/Stories/Explore,
/// YouTube Shorts) per il profilo corrente.
///
/// Regola UX enforcement: per ogni app supportata, il gruppo di toggle è
/// disabled se l'app è già nel blocklist del profilo (in quel caso è già
/// bloccata interamente, non serve filtrare sezioni).
class BlockInAppContentScreen extends ConsumerStatefulWidget {
  const BlockInAppContentScreen({super.key, required this.profileId});

  final int profileId;

  @override
  ConsumerState<BlockInAppContentScreen> createState() =>
      _BlockInAppContentScreenState();
}

class _BlockInAppContentScreenState
    extends ConsumerState<BlockInAppContentScreen> {
  /// Per ogni package supportato: set di sezioni selezionate.
  final Map<String, Set<BlockedSection>> _perApp = {};
  bool _loaded = false;

  Future<void> _hydrate() async {
    if (_loaded) return;
    final profile = await ref.read(profileByIdProvider(widget.profileId).future);
    if (!mounted) return;
    if (profile == null) return;

    for (final pkg in BlockedSection.supportedPackages) {
      final relation = profile.apps.firstWhereOrNull(
        (r) => r.packageName == pkg,
      );
      _perApp[pkg] = BlockedSection.decodeSet(relation?.blockedSectionsJson);
    }

    setState(() => _loaded = true);
  }

  /// Un'app è "interamente bloccata" se presente nelle relations con isEnabled=true.
  bool _isFullyBlocked(String packageName, ProfileModel profile) {
    final relation = profile.apps.firstWhereOrNull(
      (r) => r.packageName == packageName,
    );
    return relation?.isEnabled ?? false;
  }

  Future<void> _save() async {
    final db = ref.read(appDatabaseProvider);
    for (final entry in _perApp.entries) {
      final pkg = entry.key;
      final sections = entry.value;
      final json = sections.isEmpty ? null : BlockedSection.encodeSet(sections);

      // Upsert nella relation per questo (profileId, packageName).
      final existing = await (db.select(db.appProfileRelations)
            ..where((r) => r.profileId.equals(widget.profileId) & r.packageName.equals(pkg))
            ..limit(1))
          .getSingleOrNull();
      if (existing == null) {
        await db.into(db.appProfileRelations).insert(
              AppProfileRelationsCompanion.insert(
                profileId: widget.profileId,
                packageName: pkg,
                isEnabled: const Value(false),
                blockedSectionsJson: Value(json),
              ),
            );
      } else {
        await (db.update(db.appProfileRelations)
              ..where((r) => r.id.equals(existing.id)))
            .write(AppProfileRelationsCompanion(blockedSectionsJson: Value(json)));
      }
    }
    await ref.read(profileRepositoryProvider).setAppsForProfile(
          widget.profileId,
          // preserve current blocklist by re-writing it intact
          (await ref.read(profileByIdProvider(widget.profileId).future))
                  ?.apps
                  .where((r) => r.isEnabled)
                  .map((r) => r.packageName)
                  .toList() ??
              const [],
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) _hydrate();
    final profileAsync = ref.watch(profileByIdProvider(widget.profileId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('In-app content'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              _Hint(),
              for (final pkg in BlockedSection.supportedPackages)
                _AppGroup(
                  packageName: pkg,
                  sections: BlockedSection.forPackage(pkg),
                  isFullyBlocked: _isFullyBlocked(pkg, profile),
                  selected: _perApp[pkg] ?? const {},
                  onToggle: (section, enabled) {
                    setState(() {
                      final current = {..._perApp[pkg] ?? const {}};
                      if (enabled) {
                        current.add(section);
                      } else {
                        current.remove(section);
                      }
                      _perApp[pkg] = current;
                    });
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(
        'Block specific sections inside an app. If the whole app is '
        'already on this profile\'s blocklist, sections are redundant and '
        'disabled.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: KoruColors.textSecondary,
              height: 1.4,
            ),
      ),
    );
  }
}

class _AppGroup extends StatelessWidget {
  const _AppGroup({
    required this.packageName,
    required this.sections,
    required this.isFullyBlocked,
    required this.selected,
    required this.onToggle,
  });

  final String packageName;
  final List<BlockedSection> sections;
  final bool isFullyBlocked;
  final Set<BlockedSection> selected;
  final void Function(BlockedSection, bool) onToggle;

  String get _appLabel {
    switch (packageName) {
      case 'com.instagram.android':
        return 'Instagram';
      case 'com.google.android.youtube':
        return 'YouTube';
      default:
        return packageName;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  _appLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                if (isFullyBlocked)
                  Chip(
                    label: const Text('Fully blocked'),
                    backgroundColor: KoruColors.primary.withValues(alpha: 0.2),
                    padding: EdgeInsets.zero,
                    labelStyle: const TextStyle(fontSize: 11),
                  ),
              ],
            ),
          ),
          ...sections.map((s) {
            final label = s.displayName.replaceFirst('$_appLabel ', '');
            // Se l'app è fully blocked, la sezione è implicitamente ON anche
            // se blockedSectionsJson è null/vuoto: il blocco totale copre
            // tutte le sezioni dell'app.
            return SwitchListTile(
              value: isFullyBlocked || selected.contains(s),
              onChanged: isFullyBlocked ? null : (v) => onToggle(s, v),
              title: Text(label),
              subtitle: isFullyBlocked
                  ? Text(
                      'Section blocking disabled: app is fully blocked in this profile.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: KoruColors.textSecondary,
                          ),
                    )
                  : null,
            );
          }),
        ],
      ),
    );
  }
}
