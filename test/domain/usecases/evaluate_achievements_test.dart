import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/achievement.dart';
import 'package:koru/domain/usecases/evaluate_achievements.dart';
import 'package:mocktail/mocktail.dart';

class MockAchievementsGateway extends Mock implements AchievementsGateway {}

AchievementStats _baseStats({
  int totalFocusMinutes = 0,
  int focusMinutesToday = 0,
  int focusStreakCurrent = 0,
  int cleanStreakCurrent = 0,
  int intentionsCount = 0,
  int honestBlocksCount = 0,
  int profilesCount = 0,
  int appsWithLimitsCount = 0,
  bool strictModeEnabled = false,
  int appsWithCustomOverlayCount = 0,
}) {
  return AchievementStats(
    totalFocusMinutes: totalFocusMinutes,
    focusMinutesToday: focusMinutesToday,
    focusStreakCurrent: focusStreakCurrent,
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

    test('totalFocusMinutes=1 unlocks only focus_first', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(totalFocusMinutes: 1),
        repo: repo,
      );
      expect(_ids(result), {'focus_first'});
      verify(() => repo.unlock('focus_first')).called(1);
    });

    test('totalFocusMinutes=60 unlocks focus_first + focus_hour', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(totalFocusMinutes: 60),
        repo: repo,
      );
      expect(_ids(result), {'focus_first', 'focus_hour'});
    });

    test('totalFocusMinutes=240 + focusMinutesToday=240 unlocks focus_first, '
        'focus_hour, focus_day (NOT focus_dedicated/focus_monk)', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(totalFocusMinutes: 240, focusMinutesToday: 240),
        repo: repo,
      );
      expect(_ids(result), {'focus_first', 'focus_hour', 'focus_day'});
      expect(_ids(result), isNot(contains('focus_dedicated')));
      expect(_ids(result), isNot(contains('focus_monk')));
    });

    test('totalFocusMinutes=600 unlocks all focus except focus_monk', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(totalFocusMinutes: 600, focusMinutesToday: 600),
        repo: repo,
      );
      expect(
        _ids(result),
        containsAll({
          'focus_first',
          'focus_hour',
          'focus_day',
          'focus_dedicated',
        }),
      );
      expect(_ids(result), isNot(contains('focus_monk')));
    });

    test('totalFocusMinutes=3000 unlocks all focus achievements', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(totalFocusMinutes: 3000, focusMinutesToday: 3000),
        repo: repo,
      );
      expect(
        _ids(result),
        containsAll({
          'focus_first',
          'focus_hour',
          'focus_day',
          'focus_dedicated',
          'focus_monk',
        }),
      );
    });

    test('focusStreakCurrent=7 unlocks streak_focus_7 only', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(focusStreakCurrent: 7),
        repo: repo,
      );
      expect(_ids(result), {'streak_focus_7'});
    });

    test('focusStreakCurrent=100 unlocks all three streak_focus_* '
        'achievements', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(focusStreakCurrent: 100),
        repo: repo,
      );
      expect(
        _ids(result),
        containsAll({'streak_focus_7', 'streak_focus_30', 'streak_focus_100'}),
      );
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

    test('all targets met → all 15 achievements unlocked', () async {
      final result = await evaluateAchievements(
        stats: _baseStats(
          totalFocusMinutes: 3000,
          focusMinutesToday: 240,
          focusStreakCurrent: 100,
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
      expect(result, hasLength(15));
      expect(_ids(result), equals(kAchievementCatalog.map((a) => a.id).toSet()));
    });

    test('already-unlocked achievement is not re-unlocked '
        'nor reported', () async {
      when(() => repo.getUnlockedIds())
          .thenAnswer((_) async => {'focus_first'});

      final result = await evaluateAchievements(
        stats: _baseStats(totalFocusMinutes: 1),
        repo: repo,
      );
      expect(result, isEmpty);
      verifyNever(() => repo.unlock('focus_first'));
    });

    test('repo.unlock returning false (race condition) excludes achievement '
        'from result', () async {
      when(() => repo.unlock('focus_first')).thenAnswer((_) async => false);

      final result = await evaluateAchievements(
        stats: _baseStats(totalFocusMinutes: 60),
        repo: repo,
      );
      expect(_ids(result), {'focus_hour'});
      verify(() => repo.unlock('focus_first')).called(1);
      verify(() => repo.unlock('focus_hour')).called(1);
    });

    test('skips already-unlocked even when satisfied; unlocks the rest',
        () async {
      when(() => repo.getUnlockedIds())
          .thenAnswer((_) async => {'focus_first', 'focus_hour'});

      final result = await evaluateAchievements(
        stats: _baseStats(totalFocusMinutes: 240, focusMinutesToday: 240),
        repo: repo,
      );
      expect(_ids(result), {'focus_day'});
      verifyNever(() => repo.unlock('focus_first'));
      verifyNever(() => repo.unlock('focus_hour'));
      verify(() => repo.unlock('focus_day')).called(1);
    });
  });

  group('achievementProgress', () {
    Achievement byId(String id) =>
        kAchievementCatalog.firstWhere((a) => a.id == id);

    test('focus_first: 0 → 0, 1 → 1, 100 → 1', () {
      final a = byId('focus_first');
      expect(achievementProgress(a, _baseStats(totalFocusMinutes: 0)), 0);
      expect(achievementProgress(a, _baseStats(totalFocusMinutes: 1)), 1);
      expect(achievementProgress(a, _baseStats(totalFocusMinutes: 100)), 1);
    });

    test('focus_hour clamps to 60', () {
      final a = byId('focus_hour');
      expect(achievementProgress(a, _baseStats(totalFocusMinutes: 30)), 30);
      expect(achievementProgress(a, _baseStats(totalFocusMinutes: 60)), 60);
      expect(achievementProgress(a, _baseStats(totalFocusMinutes: 200)), 60);
    });

    test('focus_day clamps to 240', () {
      final a = byId('focus_day');
      expect(achievementProgress(a, _baseStats(focusMinutesToday: 0)), 0);
      expect(achievementProgress(a, _baseStats(focusMinutesToday: 100)), 100);
      expect(achievementProgress(a, _baseStats(focusMinutesToday: 500)), 240);
    });

    test('focus_dedicated clamps to 600', () {
      final a = byId('focus_dedicated');
      expect(achievementProgress(a, _baseStats(totalFocusMinutes: 300)), 300);
      expect(achievementProgress(a, _baseStats(totalFocusMinutes: 600)), 600);
      expect(achievementProgress(a, _baseStats(totalFocusMinutes: 10000)), 600);
    });

    test('focus_monk clamps to 3000', () {
      final a = byId('focus_monk');
      expect(achievementProgress(a, _baseStats(totalFocusMinutes: 1500)), 1500);
      expect(achievementProgress(a, _baseStats(totalFocusMinutes: 3000)), 3000);
      expect(achievementProgress(a, _baseStats(totalFocusMinutes: 99999)), 3000);
    });

    test('streak_focus_7 clamps to 7', () {
      final a = byId('streak_focus_7');
      expect(achievementProgress(a, _baseStats(focusStreakCurrent: 3)), 3);
      expect(achievementProgress(a, _baseStats(focusStreakCurrent: 7)), 7);
      expect(achievementProgress(a, _baseStats(focusStreakCurrent: 50)), 7);
    });

    test('streak_focus_30 clamps to 30', () {
      final a = byId('streak_focus_30');
      expect(achievementProgress(a, _baseStats(focusStreakCurrent: 15)), 15);
      expect(achievementProgress(a, _baseStats(focusStreakCurrent: 30)), 30);
      expect(achievementProgress(a, _baseStats(focusStreakCurrent: 200)), 30);
    });

    test('streak_focus_100 clamps to 100', () {
      final a = byId('streak_focus_100');
      expect(achievementProgress(a, _baseStats(focusStreakCurrent: 80)), 80);
      expect(achievementProgress(a, _baseStats(focusStreakCurrent: 100)), 100);
      expect(achievementProgress(a, _baseStats(focusStreakCurrent: 200)), 100);
    });

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
        category: AchievementCategory.focus,
        target: 10,
      );
      expect(
        achievementProgress(
          fake,
          _baseStats(
            totalFocusMinutes: 9999,
            focusMinutesToday: 9999,
            focusStreakCurrent: 9999,
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
