import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/achievement.dart';
import 'package:koru/domain/usecases/evaluate_achievements.dart';
import 'package:mocktail/mocktail.dart';

class MockAchievementsGateway extends Mock implements AchievementsGateway {}

AchievementStats _baseStats({
  int cleanStreakCurrent = 0,
  int intentionsCount = 0,
  int honestBlocksCount = 0,
  int profilesCount = 0,
  int appsWithLimitsCount = 0,
  bool strictModeEnabled = false,
  int appsWithCustomOverlayCount = 0,
}) {
  return AchievementStats(
    cleanStreakCurrent: cleanStreakCurrent,
    intentionsCount: intentionsCount,
    honestBlocksCount: honestBlocksCount,
    profilesCount: profilesCount,
    appsWithLimitsCount: appsWithLimitsCount,
    strictModeEnabled: strictModeEnabled,
    appsWithCustomOverlayCount: appsWithCustomOverlayCount,
  );
}

Set<String> _ids(List<Achievement> list) => list.map((a) => a.id).toSet();

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  group('evaluateAchievements', () {
    late MockAchievementsGateway repo;

    setUp(() {
      repo = MockAchievementsGateway();
      when(() => repo.getUnlockedIds()).thenAnswer((_) async => <String>{});
      when(() => repo.unlock(any())).thenAnswer((_) async => true);
    });

    test('zeroed stats unlock no achievements', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(),
        repo: repo,
      );
      expect(result, isEmpty);
      verifyNever(() => repo.unlock(any()));
    });

    test('cleanStreakCurrent=7 unlocks clean_week', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(cleanStreakCurrent: 7),
        repo: repo,
      );
      expect(_ids(result), {'clean_week'});
    });

    test('intentionsCount=50 unlocks intentions_50', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(intentionsCount: 50),
        repo: repo,
      );
      expect(_ids(result), {'intentions_50'});
    });

    test('honestBlocksCount=100 unlocks honest_block_100', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(honestBlocksCount: 100),
        repo: repo,
      );
      expect(_ids(result), {'honest_block_100'});
    });

    test('profilesCount=1 unlocks setup_first_profile', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(profilesCount: 1),
        repo: repo,
      );
      expect(_ids(result), {'setup_first_profile'});
    });

    test('appsWithLimitsCount=3 unlocks setup_curated', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(appsWithLimitsCount: 3),
        repo: repo,
      );
      expect(_ids(result), {'setup_curated'});
    });

    test('strictModeEnabled=true unlocks setup_lockdown', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(strictModeEnabled: true),
        repo: repo,
      );
      expect(_ids(result), {'setup_lockdown'});
    });

    test('appsWithCustomOverlayCount=1 unlocks setup_customized', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(appsWithCustomOverlayCount: 1),
        repo: repo,
      );
      expect(_ids(result), {'setup_customized'});
    });

    test('all targets met → all 7 achievements unlocked', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(
          cleanStreakCurrent: 7,
          intentionsCount: 50,
          honestBlocksCount: 100,
          profilesCount: 1,
          appsWithLimitsCount: 3,
          strictModeEnabled: true,
          appsWithCustomOverlayCount: 1,
        ),
        repo: repo,
      );
      expect(result, hasLength(7));
      expect(_ids(result), equals(kAchievementCatalog.map((a) => a.id).toSet()));
    });

    test('already-unlocked achievement is not re-unlocked '
        'nor reported', () async {
      when(() => repo.getUnlockedIds())
          .thenAnswer((_) async => {'setup_first_profile'});

      final result = await evaluateAchievements(
        stats: _baseStats(profilesCount: 1),
        repo: repo,
      );
      expect(result, isEmpty);
      verifyNever(() => repo.unlock('setup_first_profile'));
    });

    test('repo.unlock returning false (race condition) excludes achievement '
        'from result', () async {
      when(() => repo.unlock('setup_first_profile'))
          .thenAnswer((_) async => false);

      final result = await evaluateAchievements(
        stats: _baseStats(profilesCount: 1, appsWithLimitsCount: 3),
        repo: repo,
      );
      expect(_ids(result), {'setup_curated'});
      verify(() => repo.unlock('setup_first_profile')).called(1);
      verify(() => repo.unlock('setup_curated')).called(1);
    });

    test('skips already-unlocked even when satisfied; unlocks the rest',
        () async {
      when(() => repo.getUnlockedIds())
          .thenAnswer((_) async => {'setup_first_profile', 'setup_curated'});

      final result = await evaluateAchievements(
        stats: _baseStats(
          profilesCount: 1,
          appsWithLimitsCount: 3,
          strictModeEnabled: true,
        ),
        repo: repo,
      );
      expect(_ids(result), {'setup_lockdown'});
      verifyNever(() => repo.unlock('setup_first_profile'));
      verifyNever(() => repo.unlock('setup_curated'));
      verify(() => repo.unlock('setup_lockdown')).called(1);
    });
  });

  group('achievementProgress', () {
    Achievement byId(String id) =>
        kAchievementCatalog.firstWhere((a) => a.id == id);

    test('clean_week clamps to 7', () {
      final a = byId('clean_week');
      expect(achievementProgress(a, _baseStats(cleanStreakCurrent: 3)), 3);
      expect(achievementProgress(a, _baseStats(cleanStreakCurrent: 7)), 7);
      expect(achievementProgress(a, _baseStats(cleanStreakCurrent: 20)), 7);
    });

    test('intentions_50 clamps to 50', () {
      final a = byId('intentions_50');
      expect(achievementProgress(a, _baseStats(intentionsCount: 25)), 25);
      expect(achievementProgress(a, _baseStats(intentionsCount: 50)), 50);
      expect(achievementProgress(a, _baseStats(intentionsCount: 999)), 50);
    });

    test('honest_block_100 clamps to 100', () {
      final a = byId('honest_block_100');
      expect(achievementProgress(a, _baseStats(honestBlocksCount: 50)), 50);
      expect(achievementProgress(a, _baseStats(honestBlocksCount: 100)), 100);
      expect(achievementProgress(a, _baseStats(honestBlocksCount: 500)), 100);
    });

    test('setup_first_profile: 0 → 0, 1+ → 1', () {
      final a = byId('setup_first_profile');
      expect(achievementProgress(a, _baseStats(profilesCount: 0)), 0);
      expect(achievementProgress(a, _baseStats(profilesCount: 1)), 1);
      expect(achievementProgress(a, _baseStats(profilesCount: 12)), 1);
    });

    test('setup_curated clamps to 3', () {
      final a = byId('setup_curated');
      expect(achievementProgress(a, _baseStats(appsWithLimitsCount: 0)), 0);
      expect(achievementProgress(a, _baseStats(appsWithLimitsCount: 2)), 2);
      expect(achievementProgress(a, _baseStats(appsWithLimitsCount: 3)), 3);
      expect(achievementProgress(a, _baseStats(appsWithLimitsCount: 99)), 3);
    });

    test('setup_lockdown: false → 0, true → 1', () {
      final a = byId('setup_lockdown');
      expect(achievementProgress(a, _baseStats(strictModeEnabled: false)), 0);
      expect(achievementProgress(a, _baseStats(strictModeEnabled: true)), 1);
    });

    test('setup_customized: 0 → 0, 1+ → 1', () {
      final a = byId('setup_customized');
      expect(
          achievementProgress(a, _baseStats(appsWithCustomOverlayCount: 0)), 0);
      expect(
          achievementProgress(a, _baseStats(appsWithCustomOverlayCount: 1)), 1);
      expect(
          achievementProgress(a, _baseStats(appsWithCustomOverlayCount: 5)), 1);
    });

    test('unknown achievement id returns 0', () {
      const fake = Achievement(
        id: 'totally_made_up_id',
        title: 'Fake',
        description: 'Fake',
        iconKey: 'help_outline',
        category: AchievementCategory.setup,
        target: 10,
      );
      expect(
        achievementProgress(
          fake,
          _baseStats(
            cleanStreakCurrent: 9999,
            intentionsCount: 9999,
            honestBlocksCount: 9999,
            profilesCount: 9999,
            appsWithLimitsCount: 9999,
            strictModeEnabled: true,
            appsWithCustomOverlayCount: 9999,
          ),
        ),
        0,
      );
    });
  });
}
