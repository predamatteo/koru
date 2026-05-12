import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';
import 'package:koru/data/repositories/preset_repository.dart';
import 'package:koru/data/repositories/profile_repository.dart';
import 'package:koru/platform/profile_channel.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileChannel extends Mock implements ProfileChannel {}

void main() {
  group('KoruPreset.fromJson', () {
    test('parses every documented field from a full JSON payload', () {
      final raw = jsonDecode('''
{
  "presetId": 1,
  "title": "Mindful Morning",
  "emoji": "🌅",
  "colorHex": "#8A6D52",
  "dayFlags": 127,
  "blockingMode": 0,
  "typeCombinations": 1,
  "intervals": [
    { "fromMinutes": 420, "toMinutes": 540 }
  ],
  "blockedPackages": ["com.a", "com.b"]
}
''') as Map<String, dynamic>;

      final preset = KoruPreset.fromJson(raw);
      expect(preset.presetId, 1);
      expect(preset.title, 'Mindful Morning');
      expect(preset.emoji, '🌅');
      expect(preset.colorHex, '#8A6D52');
      expect(preset.dayFlags, 127);
      expect(preset.blockingMode, 0);
      expect(preset.typeCombinations, 1);
      expect(preset.intervals, hasLength(1));
      expect(preset.intervals.single.fromMinutes, 420);
      expect(preset.intervals.single.toMinutes, 540);
      expect(preset.blockedPackages, ['com.a', 'com.b']);
    });

    test('supports an empty intervals array', () {
      final raw = jsonDecode('''
{
  "presetId": 99,
  "title": "Empty",
  "emoji": "X",
  "colorHex": "#000000",
  "dayFlags": 0,
  "blockingMode": 1,
  "typeCombinations": 64,
  "intervals": [],
  "blockedPackages": []
}
''') as Map<String, dynamic>;

      final preset = KoruPreset.fromJson(raw);
      expect(preset.intervals, isEmpty);
      expect(preset.blockedPackages, isEmpty);
      expect(preset.blockingMode, 1);
    });

    test('supports multiple intervals in the same preset', () {
      final raw = jsonDecode('''
{
  "presetId": 99,
  "title": "Multi",
  "emoji": "X",
  "colorHex": "#000000",
  "dayFlags": 127,
  "blockingMode": 0,
  "typeCombinations": 1,
  "intervals": [
    { "fromMinutes": 540, "toMinutes": 720 },
    { "fromMinutes": 840, "toMinutes": 1020 }
  ],
  "blockedPackages": ["com.a"]
}
''') as Map<String, dynamic>;

      final preset = KoruPreset.fromJson(raw);
      expect(preset.intervals, hasLength(2));
      expect(preset.intervals[0].fromMinutes, 540);
      expect(preset.intervals[1].toMinutes, 1020);
    });
  });

  group('PresetRepository.loadAll (real asset bundle)', () {
    // Loading assets requires the test binding.
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('loads exactly the 3 bundled presets', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final channel = _MockProfileChannel();
      when(() => channel.notifyProfileChanged(any())).thenAnswer((_) async {});
      final profileRepo = ProfileRepository(db: db, channel: channel);
      final repo = PresetRepository(profileRepo);

      final presets = await repo.loadAll();
      expect(presets, hasLength(3));
      // The 3 presets are mindful_morning (id=1), deep_work (id=2),
      // no_screen_evening (id=3). Order is preserved from the source list.
      expect(presets.map((p) => p.presetId).toList(), [1, 2, 3]);
      expect(presets.map((p) => p.title).toSet(), {
        'Mindful Morning',
        'Deep Work',
        'No Screen Evening',
      });

      await db.close();
    });
  });

  group('PresetRepository.apply', () {
    late AppDatabase db;
    late _MockProfileChannel channel;
    late ProfileRepository profileRepo;
    late PresetRepository repo;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      channel = _MockProfileChannel();
      when(() => channel.notifyProfileChanged(any())).thenAnswer((_) async {});
      profileRepo = ProfileRepository(db: db, channel: channel);
      repo = PresetRepository(profileRepo);
    });

    tearDown(() async {
      await db.close();
    });

    test('creates a Profile row populated from the preset fields', () async {
      final preset = KoruPreset(
        presetId: 7,
        title: 'Test Preset',
        emoji: '⚡',
        colorHex: '#123456',
        dayFlags: 31,
        blockingMode: 0,
        typeCombinations: 1,
        intervals: const [(fromMinutes: 540, toMinutes: 720)],
        blockedPackages: const ['com.a', 'com.b'],
      );

      final id = await repo.apply(preset);
      expect(id, greaterThan(0));

      final row = await db.getProfileById(id);
      expect(row, isNotNull);
      expect(row!.title, 'Test Preset');
      expect(row.emoji, '⚡');
      expect(row.colorHex, '#123456');
      expect(row.dayFlags, 31);
      expect(row.blockingMode, 0);
      expect(row.typeCombinations, 1);
      expect(row.presetId, 7);
    });

    test('inserts every interval declared in the preset', () async {
      final preset = KoruPreset(
        presetId: 7,
        title: 'I',
        emoji: 'X',
        colorHex: '#000000',
        dayFlags: 127,
        blockingMode: 0,
        typeCombinations: 1,
        intervals: const [
          (fromMinutes: 540, toMinutes: 720),
          (fromMinutes: 840, toMinutes: 1020),
        ],
        blockedPackages: const [],
      );

      final id = await repo.apply(preset);
      final ivs = await db.getIntervalsForProfile(id);
      expect(ivs, hasLength(2));
      expect(
        ivs.map((iv) => (iv.fromMinutes, iv.toMinutes)).toSet(),
        {(540, 720), (840, 1020)},
      );
    });

    test('inserts an AppProfileRelation row for every blocked package',
        () async {
      final preset = KoruPreset(
        presetId: 7,
        title: 'A',
        emoji: 'X',
        colorHex: '#000000',
        dayFlags: 127,
        blockingMode: 0,
        typeCombinations: 1,
        intervals: const [],
        blockedPackages: const ['com.a', 'com.b', 'com.c'],
      );

      final id = await repo.apply(preset);
      final rels = await db.getAppsForProfile(id);
      expect(
        rels.map((r) => r.packageName).toSet(),
        {'com.a', 'com.b', 'com.c'},
      );
    });

    test('apply on an empty preset still creates the profile', () async {
      final preset = KoruPreset(
        presetId: 99,
        title: 'Empty',
        emoji: 'X',
        colorHex: '#000000',
        dayFlags: 0,
        blockingMode: 1,
        typeCombinations: 64,
        intervals: const [],
        blockedPackages: const [],
      );
      final id = await repo.apply(preset);
      final row = await db.getProfileById(id);
      expect(row, isNotNull);
      expect(await db.getIntervalsForProfile(id), isEmpty);
      expect(await db.getAppsForProfile(id), isEmpty);
    });
  });
}
