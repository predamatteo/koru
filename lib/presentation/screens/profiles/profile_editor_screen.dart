import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/day_flags.dart';
import '../../../core/constants/koru_colors.dart';
import '../../../core/constants/layout.dart';
import '../../../core/constants/profile_types.dart';
import '../../../core/di/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/entities/blocked_section.dart';
import '../../providers/achievements_provider.dart';
import '../../providers/profile_providers.dart';
import '../../widgets/koru_pull_to_refresh.dart';

class ProfileEditorScreen extends ConsumerStatefulWidget {
  const ProfileEditorScreen({super.key, this.profileId});
  final int? profileId;

  bool get isNew => profileId == null;

  @override
  ConsumerState<ProfileEditorScreen> createState() =>
      _ProfileEditorScreenState();
}

/// Set minimo di emoji adatte a profili.
const List<String> _emojiPalette = [
  '🌿',
  '🌅',
  '🌙',
  '🧠',
  '💼',
  '🎯',
  '📚',
  '🏃',
  '🧘',
  '🛌',
  '☕',
  '🔕',
];

class _ProfileEditorScreenState extends ConsumerState<ProfileEditorScreen> {
  final _titleController = TextEditingController();
  String _emoji = '🌿';
  int _dayFlags = DayFlags.allDays;
  int _blockingMode = BlockingMode.blocklist;
  int _typeCombinations = ProfileType.time;
  List<_TimeSlotData> _slots = [
    _TimeSlotData(
      from: const TimeOfDay(hour: 9, minute: 0),
      to: const TimeOfDay(hour: 17, minute: 0),
    ),
  ];
  bool _timeEnabled = true;
  bool _loaded = false;
  List<String> _wifiSsids = const [];
  Set<BlockedSection> _blockedSections = {};
  Set<String> _fullyBlockedPkgs = const {};
  int _appsCount = 0;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting(int id) async {
    if (_loaded) return;
    // refresh forzato: profileByIdProvider e' un FutureProvider cached, quindi
    // senza ricaricare esplicitamente l'editor riaperto dopo un save vedrebbe
    // lo snapshot precedente (intervals di prima dell'aggiunta slot, ecc.)
    // e un successivo salvataggio sovrascriverebbe i dati freschi in DB.
    final profile = await ref.refresh(profileByIdProvider(id).future);
    if (profile == null || !mounted) return;
    final wifis = await ref
        .read(profileRepositoryProvider)
        .getWifisForProfile(id);
    if (!mounted) return;

    // Carica le sezioni in-app dalle relations del profilo. Includiamo anche
    // le app interamente bloccate: per quelle le sezioni vengono
    // auto-popolate (vedi ProfileRepository.setAppsForProfile) e la UI le
    // mostra come ON + disabled, per comunicare che sono "implicate" dal
    // blocco totale.
    final sections = <BlockedSection>{};
    final fullyBlocked = <String>{};
    for (final rel in profile.apps) {
      if (rel.isEnabled) fullyBlocked.add(rel.packageName);
      sections.addAll(BlockedSection.decodeSet(rel.blockedSectionsJson));
    }
    final appsCount = profile.apps.where((a) => a.isEnabled).length;

    setState(() {
      _loaded = true;
      _titleController.text = profile.title;
      _emoji = profile.emoji == 'NoIcon' ? '🌿' : profile.emoji;
      _dayFlags = profile.dayFlags;
      _blockingMode = profile.blockingMode;
      _typeCombinations = profile.typeCombinations;
      _timeEnabled = ProfileType.hasType(_typeCombinations, ProfileType.time);
      if (profile.intervals.isNotEmpty) {
        _slots = [
          for (final iv in profile.intervals)
            _TimeSlotData(
              from: TimeOfDay(
                hour: iv.fromMinutes ~/ 60,
                minute: iv.fromMinutes % 60,
              ),
              to: TimeOfDay(
                hour: iv.toMinutes ~/ 60,
                minute: iv.toMinutes % 60,
              ),
            ),
        ];
      }
      _wifiSsids = wifis;
      _blockedSections = sections;
      _fullyBlockedPkgs = fullyBlocked;
      _appsCount = appsCount;
    });
  }

  Future<void> _addCurrentWifi() async {
    final ssid = await ProfilesWifiHelper.readCurrentSsid(ref);
    if (ssid == null || ssid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not read current SSID. Ensure WiFi is on and location permission is granted.',
            ),
          ),
        );
      }
      return;
    }
    if (_wifiSsids.contains(ssid)) return;
    setState(() => _wifiSsids = [..._wifiSsids, ssid]);
    if (!widget.isNew && widget.profileId != null) {
      await ref
          .read(profileRepositoryProvider)
          .setWifisForProfile(widget.profileId!, _wifiSsids);
    }
  }

  Future<void> _addManualWifi() async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add WiFi SSID'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Home_WiFi'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    if (_wifiSsids.contains(result)) return;
    setState(() => _wifiSsids = [..._wifiSsids, result]);
    if (!widget.isNew && widget.profileId != null) {
      await ref
          .read(profileRepositoryProvider)
          .setWifisForProfile(widget.profileId!, _wifiSsids);
    }
  }

  Future<void> _removeWifi(String ssid) async {
    setState(() => _wifiSsids = _wifiSsids.where((s) => s != ssid).toList());
    if (!widget.isNew && widget.profileId != null) {
      await ref
          .read(profileRepositoryProvider)
          .setWifisForProfile(widget.profileId!, _wifiSsids);
    }
  }

  Future<void> _toggleSection(BlockedSection s, bool on) async {
    setState(() {
      if (on) {
        _blockedSections = {..._blockedSections, s};
      } else {
        _blockedSections = {..._blockedSections}..remove(s);
      }
    });
    // Persist immediato solo se profilo esistente.
    if (!widget.isNew && widget.profileId != null) {
      await _persistSectionsForPackage(s.packageName);
    }
  }

  /// Aggiorna o crea la relation per `packageName` con il subset
  /// corrente di [BlockedSection] rilevanti per quel package.
  Future<void> _persistSectionsForPackage(String packageName) async {
    final profileId = widget.profileId!;
    final db = ref.read(appDatabaseProvider);
    final relevant = _blockedSections
        .where((s) => s.packageName == packageName)
        .toSet();
    final json = BlockedSection.encodeSet(relevant);
    final existing =
        await (db.select(db.appProfileRelations)
              ..where(
                (r) =>
                    r.profileId.equals(profileId) &
                    r.packageName.equals(packageName),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing == null) {
      await db
          .into(db.appProfileRelations)
          .insert(
            AppProfileRelationsCompanion.insert(
              profileId: profileId,
              packageName: packageName,
              isEnabled: const d.Value(false),
              blockedSectionsJson: d.Value(json),
            ),
          );
    } else {
      await (db.update(
        db.appProfileRelations,
      )..where((r) => r.id.equals(existing.id))).write(
        AppProfileRelationsCompanion(blockedSectionsJson: d.Value(json)),
      );
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name the profile first')));
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
        for (final s in _slots)
          (
            from: s.from.hour * 60 + s.from.minute,
            to: s.to.hour * 60 + s.to.minute,
          ),
      ]);
    } else {
      await repo.setIntervalsForProfile(profileId, const []);
    }

    await repo.setWifisForProfile(profileId, _wifiSsids);

    // Persist sezioni per tutti i pacchetti coinvolti (anche quelli
    // svuotati, per garantire coerenza al save del nuovo profilo).
    if (widget.isNew) {
      for (final pkg in BlockedSection.supportedPackages) {
        // workaround: uso il nuovo profileId con un salvataggio manuale.
        final relevant = _blockedSections
            .where((s) => s.packageName == pkg)
            .toSet();
        if (relevant.isEmpty) continue;
        final db = ref.read(appDatabaseProvider);
        await db
            .into(db.appProfileRelations)
            .insert(
              AppProfileRelationsCompanion.insert(
                profileId: profileId,
                packageName: pkg,
                isEnabled: const d.Value(false),
                blockedSectionsJson: d.Value(
                  BlockedSection.encodeSet(relevant),
                ),
              ),
            );
      }
    }

    await ref.read(achievementEvaluationProvider.notifier).trigger();
    // Invalidate cache del profilo: ri-aprire l'editor (o una sub-screen che
    // watcha profileByIdProvider) deve vedere i nuovi intervals/wifi/sezioni,
    // non lo snapshot cached in memoria.
    ref.invalidate(profileByIdProvider(profileId));
    if (mounted) context.pop();
  }

  Future<void> _pickTime(int slotIndex, bool isStart) async {
    final slot = _slots[slotIndex];
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? slot.from : slot.to,
    );
    if (picked == null) return;
    setState(() {
      _slots[slotIndex] = isStart
          ? slot.copyWith(from: picked)
          : slot.copyWith(to: picked);
    });
  }

  void _addSlot() {
    // Suggerisce una finestra pomeridiana plausibile se non confligge,
    // altrimenti un semplice slot 1h dopo l'ultimo.
    final last = _slots.last;
    final suggestedStart = TimeOfDay(
      hour: (last.to.hour + 1) % 24,
      minute: last.to.minute,
    );
    final suggestedEnd = TimeOfDay(
      hour: (suggestedStart.hour + 2) % 24,
      minute: suggestedStart.minute,
    );
    setState(() {
      _slots = [
        ..._slots,
        _TimeSlotData(from: suggestedStart, to: suggestedEnd),
      ];
    });
  }

  void _removeSlot(int index) {
    if (_slots.length <= 1) return;
    setState(() {
      _slots = [..._slots]..removeAt(index);
    });
  }

  Future<void> _pickEmoji() async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: KoruColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pick an icon',
                style: TextStyle(
                  color: KoruColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final e in _emojiPalette)
                    InkWell(
                      onTap: () => Navigator.of(ctx).pop(e),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: KoruColors.primary.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) setState(() => _emoji = chosen);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isNew && !_loaded) {
      _loadExisting(widget.profileId!);
    }

    // Listen reattivo a profilesProvider (StreamProvider, reattivo ai
    // cambi DB via Drift): quando una sub-screen salva (blocked apps,
    // in-app sections, websites) il numero mostrato nelle card qui deve
    // aggiornarsi senza richiedere di uscire/rientrare dall'editor.
    ref.listen(profilesProvider, (prev, next) {
      if (widget.isNew) return;
      final list = next.valueOrNull;
      if (list == null) return;
      final profile = list.where((p) => p.id == widget.profileId).firstOrNull;
      if (profile == null || !mounted) return;
      final newAppsCount = profile.apps.where((a) => a.isEnabled).length;
      final newSections = <BlockedSection>{};
      final newFullyBlocked = <String>{};
      for (final rel in profile.apps) {
        if (rel.isEnabled) newFullyBlocked.add(rel.packageName);
        newSections.addAll(BlockedSection.decodeSet(rel.blockedSectionsJson));
      }
      if (newAppsCount != _appsCount ||
          newSections != _blockedSections ||
          newFullyBlocked != _fullyBlockedPkgs) {
        setState(() {
          _appsCount = newAppsCount;
          _blockedSections = newSections;
          _fullyBlockedPkgs = newFullyBlocked;
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isNew
              ? 'New profile'
              : _titleController.text.isEmpty
              ? 'Edit profile'
              : _titleController.text,
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
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
          TextButton(
            onPressed: _save,
            style: TextButton.styleFrom(foregroundColor: KoruColors.primary),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: KoruPullToRefresh(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, kBottomNavClearance),
          children: [
            // ── Identity ────────────────────────────────────────────────
            _IdentityCard(
              emoji: _emoji,
              titleController: _titleController,
              onEmojiTap: _pickEmoji,
              onTitleChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            // ── Schedule ────────────────────────────────────────────────
            const _Label('Schedule'),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                children: [
                  _DayCircles(
                    dayFlags: _dayFlags,
                    onToggle: (day) {
                      setState(
                        () => _dayFlags = DayFlags.toggleDay(_dayFlags, day),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  Container(height: 1, color: KoruColors.surfaceElevated),
                  for (var i = 0; i < _slots.length; i++) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeSlot(
                            label: 'Start',
                            time: _slots[i].from,
                            onTap: () => _pickTime(i, true),
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 1,
                          color: KoruColors.surfaceElevated,
                        ),
                        Expanded(
                          child: _TimeSlot(
                            label: 'End',
                            time: _slots[i].to,
                            onTap: () => _pickTime(i, false),
                            alignEnd: _slots.length == 1,
                          ),
                        ),
                        if (_slots.length > 1)
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: KoruColors.textSecondary,
                            ),
                            onPressed: () => _removeSlot(i),
                            tooltip: 'Remove time slot',
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    if (i < _slots.length - 1)
                      Container(
                        margin: const EdgeInsets.only(top: 14),
                        height: 1,
                        color: KoruColors.surfaceElevated,
                      ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addSlot,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add time slot'),
                      style: TextButton.styleFrom(
                        foregroundColor: KoruColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Blocked apps ───────────────────────────────────────────
            const _Label('Blocked apps'),
            const SizedBox(height: 10),
            _Card(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: KoruColors.dangerContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_appsCount',
                      style: const TextStyle(
                        color: KoruColors.danger,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Apps selected',
                      style: TextStyle(
                        color: KoruColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: KoruColors.primary,
                    ),
                    onPressed: widget.isNew
                        ? null
                        : () => context.push(
                            '/profiles/${widget.profileId}/apps',
                          ),
                    child: const Text(
                      'Configure',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.isNew)
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Text(
                  'Save the profile first to pick apps.',
                  style: TextStyle(
                    color: KoruColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // ── In-app content ─────────────────────────────────────────
            const _Label('In-app content'),
            const SizedBox(height: 10),
            _Card(
              padded: false,
              child: Column(
                children: [
                  for (var i = 0; i < BlockedSection.values.length; i++) ...[
                    () {
                      final s = BlockedSection.values[i];
                      final impliedByFullBlock = _fullyBlockedPkgs.contains(
                        s.packageName,
                      );
                      return _SectionSwitchRow(
                        section: s,
                        value:
                            impliedByFullBlock || _blockedSections.contains(s),
                        impliedByFullBlock: impliedByFullBlock,
                        onChanged: impliedByFullBlock
                            ? null
                            : (v) => _toggleSection(s, v),
                      );
                    }(),
                    if (i < BlockedSection.values.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: Container(
                          height: 1,
                          color: KoruColors.surfaceElevated,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Websites ───────────────────────────────────────────────
            const _Label('Websites'),
            const SizedBox(height: 10),
            _Card(
              child: InkWell(
                onTap: widget.isNew
                    ? null
                    : () => context.push(
                        '/profiles/${widget.profileId}/websites',
                      ),
                child: Row(
                  children: [
                    Icon(
                      Icons.language_outlined,
                      color: widget.isNew
                          ? KoruColors.textSecondary
                          : KoruColors.primary,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Blocked domains',
                        style: TextStyle(
                          color: KoruColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: KoruColors.textSecondary.withAlpha(140),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── WiFi ───────────────────────────────────────────────────
            const _Label('Only on Wi-Fi'),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _wifiSsids.isEmpty
                        ? 'No filter. Profile activates regardless of network.'
                        : 'Profile active only on:',
                    style: const TextStyle(
                      color: KoruColors.textSecondary,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  if (_wifiSsids.isNotEmpty) const SizedBox(height: 10),
                  for (final ssid in _wifiSsids)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.wifi,
                            size: 18,
                            color: KoruColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ssid,
                              style: const TextStyle(
                                color: KoruColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: KoruColors.textSecondary,
                            ),
                            onPressed: () => _removeWifi(ssid),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _addCurrentWifi,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: const Text('Add current'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: KoruColors.primary,
                            side: const BorderSide(color: KoruColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _addManualWifi,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add by name'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: KoruColors.primary,
                            side: const BorderSide(color: KoruColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Primitives ─────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Text(
        text.toUpperCase(),
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

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padded = true});
  final Widget child;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KoruColors.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      clipBehavior: Clip.antiAlias,
      padding: padded ? const EdgeInsets.all(20) : EdgeInsets.zero,
      child: child,
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.emoji,
    required this.titleController,
    required this.onEmojiTap,
    required this.onTitleChanged,
  });

  final String emoji;
  final TextEditingController titleController;
  final VoidCallback onEmojiTap;
  final ValueChanged<String> onTitleChanged;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          InkWell(
            onTap: onEmojiTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KoruColors.primary.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: titleController,
              onChanged: onTitleChanged,
              style: const TextStyle(
                color: KoruColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Profile name',
                hintStyle: TextStyle(color: KoruColors.textSecondary),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCircles extends StatelessWidget {
  const _DayCircles({required this.dayFlags, required this.onToggle});
  final int dayFlags;
  final ValueChanged<int> onToggle;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < DayFlags.ordered.length; i++)
          _DayCircle(
            letter: _letters[i],
            selected: DayFlags.hasDay(dayFlags, DayFlags.ordered[i]),
            onTap: () => onToggle(DayFlags.ordered[i]),
          ),
      ],
    );
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({
    required this.letter,
    required this.selected,
    required this.onTap,
  });
  final String letter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? KoruColors.primary : KoruColors.surfaceElevated,
          shape: BoxShape.circle,
        ),
        child: Text(
          letter,
          style: TextStyle(
            color: selected ? KoruColors.onPrimary : KoruColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TimeSlot extends StatelessWidget {
  const _TimeSlot({
    required this.label,
    required this.time,
    required this.onTap,
    this.alignEnd = false,
  });
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  final bool alignEnd;

  String _fmt() =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: KoruColors.textSecondary,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _fmt(),
            style: const TextStyle(
              color: KoruColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionSwitchRow extends StatelessWidget {
  const _SectionSwitchRow({
    required this.section,
    required this.value,
    required this.onChanged,
    this.impliedByFullBlock = false,
  });
  final BlockedSection section;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool impliedByFullBlock;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.displayName,
                  style: TextStyle(
                    color: impliedByFullBlock
                        ? KoruColors.textSecondary
                        : KoruColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                if (impliedByFullBlock)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'App fully blocked',
                      style: TextStyle(
                        color: KoruColors.textSecondary.withAlpha(180),
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _TimeSlotData {
  const _TimeSlotData({required this.from, required this.to});
  final TimeOfDay from;
  final TimeOfDay to;

  _TimeSlotData copyWith({TimeOfDay? from, TimeOfDay? to}) =>
      _TimeSlotData(from: from ?? this.from, to: to ?? this.to);
}

/// Helper per leggere il SSID corrente da dentro la UI profili senza
/// creare dipendenze pesanti fra screen e platform channel.
class ProfilesWifiHelper {
  static Future<String?> readCurrentSsid(WidgetRef ref) =>
      ref.read(platformChannelServiceProvider).blocking.getCurrentWifiSsid();
}
