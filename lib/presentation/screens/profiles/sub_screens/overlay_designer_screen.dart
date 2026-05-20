import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../data/database/app_database.dart';
import '../../../../domain/entities/overlay_config.dart';
import '../../../../platform/blocking_channel.dart';
import '../../../providers/achievements_provider.dart';
import '../../../providers/app_list_provider.dart';
import '../../../widgets/koru_pull_to_refresh.dart';
import '../../block_overlay/block_overlay_screen.dart';

/// Designer dell'overlay per-app-per-profilo. Permette di scegliere colore
/// sfondo, messaggio, durata countdown, shake, bypass dopo countdown.
/// Mostra anche un'anteprima live del BlockOverlayScreen.
class OverlayDesignerScreen extends ConsumerStatefulWidget {
  const OverlayDesignerScreen({
    super.key,
    required this.profileId,
    required this.packageName,
  });

  final int profileId;
  final String packageName;

  @override
  ConsumerState<OverlayDesignerScreen> createState() =>
      _OverlayDesignerScreenState();
}

class _OverlayDesignerScreenState extends ConsumerState<OverlayDesignerScreen> {
  static const _paletteHex = [
    '#5C8262', // primary (default)
    '#8A6D52', // secondary
    '#6B9B5F', // success
    '#A85449', // danger
    '#2D4A3E',
    '#1F2937',
  ];

  OverlayConfig _config = OverlayConfig.defaults;
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  bool _loaded = false;

  Future<void> _hydrate() async {
    if (_loaded) return;
    final db = ref.read(appDatabaseProvider);
    final existing =
        await (db.select(db.appProfileRelations)
              ..where(
                (r) =>
                    r.profileId.equals(widget.profileId) &
                    r.packageName.equals(widget.packageName),
              )
              ..limit(1))
            .getSingleOrNull();
    if (!mounted) return;
    setState(() {
      _loaded = true;
      if (existing != null) {
        _config = OverlayConfig.fromJsonString(existing.overlayConfigJson);
      }
      _titleController.text = _config.messageTitle ?? '';
      _subtitleController.text = _config.messageSubtitle ?? '';
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = _config.copyWith(
      messageTitle: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      messageSubtitle: _subtitleController.text.trim().isEmpty
          ? null
          : _subtitleController.text.trim(),
    );

    final db = ref.read(appDatabaseProvider);
    final json = updated.toJsonString();
    final existing =
        await (db.select(db.appProfileRelations)
              ..where(
                (r) =>
                    r.profileId.equals(widget.profileId) &
                    r.packageName.equals(widget.packageName),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing == null) {
      await db
          .into(db.appProfileRelations)
          .insert(
            AppProfileRelationsCompanion.insert(
              profileId: widget.profileId,
              packageName: widget.packageName,
              isEnabled: const Value(false),
              overlayConfigJson: Value(json),
            ),
          );
    } else {
      await (db.update(db.appProfileRelations)
            ..where((r) => r.id.equals(existing.id)))
          .write(AppProfileRelationsCompanion(overlayConfigJson: Value(json)));
    }
    await ref.read(achievementEvaluationProvider.notifier).trigger();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) _hydrate();
    final apps =
        ref.watch(installedAppsProvider).valueOrNull ??
        const <InstalledAppInfo>[];
    final app = apps.firstWhere(
      (a) => a.packageName == widget.packageName,
      orElse: () => InstalledAppInfo(
        packageName: widget.packageName,
        label: widget.packageName,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Overlay · ${app.label}'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: KoruPullToRefresh(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Preview
            AspectRatio(
              aspectRatio: 0.6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: IgnorePointer(
                  child: BlockOverlayScreen(
                    packageName: widget.packageName,
                    appLabel: app.label,
                    config: _config,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader('Background'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _paletteHex
                  .map((hex) {
                    final selected =
                        _config.backgroundColorHex.toUpperCase() ==
                        hex.toUpperCase();
                    return GestureDetector(
                      onTap: () => setState(
                        () =>
                            _config = _config.copyWith(backgroundColorHex: hex),
                      ),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: OverlayConfig(
                            backgroundColorHex: hex,
                          ).backgroundColor,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(
                                  color: KoruColors.textPrimary,
                                  width: 3,
                                )
                              : null,
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 24),
            _SectionHeader('Message'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title (optional)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subtitleController,
              decoration: const InputDecoration(
                labelText: 'Subtitle (optional)',
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader('Countdown'),
            Slider(
              value: _config.countdownSeconds.toDouble(),
              min: 3,
              max: 30,
              divisions: 27,
              label: '${_config.countdownSeconds}s',
              onChanged: (v) => setState(
                () => _config = _config.copyWith(countdownSeconds: v.round()),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _config.allowBypassAfterCountdown,
              onChanged: (v) => setState(
                () => _config = _config.copyWith(allowBypassAfterCountdown: v),
              ),
              title: const Text('Allow opening after countdown'),
              subtitle: const Text(
                'Show "Open anyway" button when countdown completes.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: KoruColors.textSecondary,
      letterSpacing: 2,
      fontWeight: FontWeight.w600,
    ),
  );
}
