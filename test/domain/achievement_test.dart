import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/achievement.dart';

void main() {
  group('kAchievementCatalog', () {
    test('contains exactly 7 entries (MVP catalog)', () {
      expect(kAchievementCatalog.length, 7);
    });

    test('all IDs are unique', () {
      final ids = kAchievementCatalog.map((a) => a.id).toList();
      final unique = ids.toSet();
      expect(unique.length, ids.length,
          reason: 'Duplicate achievement IDs found: $ids');
    });

    test('all IDs are snake_case (matches ^[a-z0-9_]+\$)', () {
      final pattern = RegExp(r'^[a-z0-9_]+$');
      for (final achievement in kAchievementCatalog) {
        expect(
          pattern.hasMatch(achievement.id),
          isTrue,
          reason: 'ID "${achievement.id}" is not snake_case',
        );
      }
    });

    test('all targets are greater than 0', () {
      for (final achievement in kAchievementCatalog) {
        expect(
          achievement.target,
          greaterThan(0),
          reason:
              'Achievement "${achievement.id}" has non-positive target ${achievement.target}',
        );
      }
    });

    test('every AchievementCategory has at least one entry', () {
      for (final category in AchievementCategory.values) {
        final count =
            kAchievementCatalog.where((a) => a.category == category).length;
        expect(
          count,
          greaterThan(0),
          reason: 'Category $category has no achievements',
        );
      }
    });

    test('category counts: discipline=3, setup=4', () {
      int countOf(AchievementCategory c) =>
          kAchievementCatalog.where((a) => a.category == c).length;

      expect(countOf(AchievementCategory.discipline), 3);
      expect(countOf(AchievementCategory.setup), 4);
      // Total must add up to catalog length.
      expect(
        countOf(AchievementCategory.discipline) +
            countOf(AchievementCategory.setup),
        7,
      );
    });

    test('gli id dei focus achievement rimossi non tornano nel catalogo', () {
      // Sono persistiti in achievements_unlocked: riusarli farebbe apparire
      // "gia' sbloccato" un achievement nuovo su chi usava la tab Focus.
      const retired = {
        'focus_first', 'focus_hour', 'focus_day', 'focus_dedicated',
        'focus_monk', 'streak_focus_7', 'streak_focus_30', 'streak_focus_100',
      };
      for (final a in kAchievementCatalog) {
        expect(retired.contains(a.id), isFalse, reason: 'id ritirato: ${a.id}');
      }
    });
  });

  group('achievementById', () {
    test('returns the correct Achievement for a known id', () {
      final result = achievementById('setup_first_profile');
      expect(result, isNotNull);
      expect(result!.id, 'setup_first_profile');
      expect(result.title, 'First profile');
      expect(result.category, AchievementCategory.setup);
      expect(result.target, 1);
    });

    test('returns null for an unknown id', () {
      expect(achievementById('nonexistent'), isNull);
    });

    test('returns null for empty id', () {
      expect(achievementById(''), isNull);
    });

    test('is case-sensitive (CLEAN_WEEK does not match clean_week)', () {
      expect(achievementById('CLEAN_WEEK'), isNull);
    });
  });
}
