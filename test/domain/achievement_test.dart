import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/achievement.dart';

void main() {
  group('kAchievementCatalog', () {
    test('contains exactly 15 entries (MVP catalog)', () {
      expect(kAchievementCatalog.length, 15);
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

    test('category counts: focus=5, consistency=3, discipline=3, setup=4', () {
      int countOf(AchievementCategory c) =>
          kAchievementCatalog.where((a) => a.category == c).length;

      expect(countOf(AchievementCategory.focus), 5);
      expect(countOf(AchievementCategory.consistency), 3);
      expect(countOf(AchievementCategory.discipline), 3);
      expect(countOf(AchievementCategory.setup), 4);
      // Total must add up to catalog length.
      expect(
        countOf(AchievementCategory.focus) +
            countOf(AchievementCategory.consistency) +
            countOf(AchievementCategory.discipline) +
            countOf(AchievementCategory.setup),
        15,
      );
    });
  });

  group('achievementById', () {
    test('returns the correct Achievement for a known id', () {
      final result = achievementById('focus_first');
      expect(result, isNotNull);
      expect(result!.id, 'focus_first');
      expect(result.title, 'First focus');
      expect(result.category, AchievementCategory.focus);
      expect(result.target, 1);
    });

    test('returns null for an unknown id', () {
      expect(achievementById('nonexistent'), isNull);
    });

    test('returns null for empty id', () {
      expect(achievementById(''), isNull);
    });

    test('is case-sensitive (FOCUS_FIRST does not match focus_first)', () {
      expect(achievementById('FOCUS_FIRST'), isNull);
    });
  });
}
