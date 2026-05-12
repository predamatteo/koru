import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/day_flags.dart';
import 'package:koru/core/constants/profile_types.dart';
import 'package:koru/data/database/app_database.dart';
import 'package:koru/data/models/profile_model.dart';

/// Builder for [Profile] (Drift DataClass) with sensible defaults.
/// Every field in [Profiles] table is required by the constructor.
Profile buildProfile({
  int id = 1,
  String title = 'My Profile',
  int typeCombinations = 0,
  int onConditions = 0,
  int operator = 0,
  int dayFlags = DayFlags.allDays,
  bool blockNotifications = true,
  bool blockLaunch = true,
  bool addNewApplications = false,
  bool isEnabled = false,
  bool isLocked = false,
  int lastStartTime = 0,
  int onUntil = 0,
  int lockedUntil = 0,
  int lockAt = 0,
  int pausedUntil = 0,
  int blockingMode = BlockingMode.blocklist,
  String emoji = 'NoIcon',
  bool blockUnsupportedBrowsers = false,
  bool blockAdultContent = false,
  int sortOrder = 0,
  String colorHex = '#5C8262',
  int? presetId,
}) {
  return Profile(
    id: id,
    title: title,
    typeCombinations: typeCombinations,
    onConditions: onConditions,
    operator: operator,
    dayFlags: dayFlags,
    blockNotifications: blockNotifications,
    blockLaunch: blockLaunch,
    addNewApplications: addNewApplications,
    isEnabled: isEnabled,
    isLocked: isLocked,
    lastStartTime: lastStartTime,
    onUntil: onUntil,
    lockedUntil: lockedUntil,
    lockAt: lockAt,
    pausedUntil: pausedUntil,
    blockingMode: blockingMode,
    emoji: emoji,
    blockUnsupportedBrowsers: blockUnsupportedBrowsers,
    blockAdultContent: blockAdultContent,
    sortOrder: sortOrder,
    colorHex: colorHex,
    presetId: presetId,
  );
}

AppProfileRelation buildAppRel(int profileId, String pkg) =>
    AppProfileRelation(
      id: 0,
      profileId: profileId,
      packageName: pkg,
      isEnabled: true,
      overlayConfigJson: null,
      blockedSectionsJson: null,
    );

WebsiteRule buildWebsiteRule(int profileId, String name) => WebsiteRule(
      id: 0,
      profileId: profileId,
      name: name,
      blockingType: 0,
      isAnywhereInUrl: false,
      isEnabled: true,
    );

Interval buildInterval(int profileId, int from, int to) => Interval(
      id: 0,
      profileId: profileId,
      fromMinutes: from,
      toMinutes: to,
      parentId: null,
      isAllDayAuto: false,
      isEnabled: true,
    );

void main() {
  group('ProfileModel constructor defaults', () {
    test('empty model: apps/websites/intervals/usageLimits default to []', () {
      final model = ProfileModel(data: buildProfile());
      expect(model.apps, isEmpty);
      expect(model.websites, isEmpty);
      expect(model.intervals, isEmpty);
      expect(model.usageLimits, isEmpty);
    });
  });

  group('ProfileModel convenience getters', () {
    test('id/title/emoji/colorHex/blockingMode delegate to data', () {
      final model = ProfileModel(
        data: buildProfile(
          id: 42,
          title: 'Deep Work',
          emoji: '🎯',
          colorHex: '#8A6D52',
          blockingMode: BlockingMode.allowlist,
        ),
      );
      expect(model.id, 42);
      expect(model.title, 'Deep Work');
      expect(model.emoji, '🎯');
      expect(model.colorHex, '#8A6D52');
      expect(model.blockingMode, BlockingMode.allowlist);
    });

    test('dayFlags/typeCombinations are forwarded', () {
      final model = ProfileModel(
        data: buildProfile(
          dayFlags: DayFlags.weekdays,
          typeCombinations: ProfileType.time | ProfileType.usageLimit,
        ),
      );
      expect(model.dayFlags, DayFlags.weekdays);
      expect(model.typeCombinations, 1 | 16);
    });

    test('isEnabled mirrors data.isEnabled', () {
      expect(ProfileModel(data: buildProfile(isEnabled: false)).isEnabled,
          isFalse);
      expect(ProfileModel(data: buildProfile(isEnabled: true)).isEnabled,
          isTrue);
    });
  });

  group('isPaused', () {
    test('false when pausedUntil == 0', () {
      expect(ProfileModel(data: buildProfile(pausedUntil: 0)).isPaused,
          isFalse);
    });

    test('true when pausedUntil is positive', () {
      expect(
        ProfileModel(data: buildProfile(pausedUntil: 1_700_000_000_000))
            .isPaused,
        isTrue,
      );
    });

    test('true when pausedUntil is the disabled-by-user sentinel (-1)', () {
      expect(
        ProfileModel(
          data: buildProfile(pausedUntil: PausedUntil.disabledByUser),
        ).isPaused,
        isTrue,
      );
    });
  });

  group('typeCombinations flags', () {
    test('hasTimeCondition reflects ProfileType.time bit', () {
      expect(
        ProfileModel(
          data: buildProfile(typeCombinations: ProfileType.time),
        ).hasTimeCondition,
        isTrue,
      );
      expect(
        ProfileModel(
          data: buildProfile(typeCombinations: 0),
        ).hasTimeCondition,
        isFalse,
      );
      // Mixed flags still detects time.
      expect(
        ProfileModel(
          data: buildProfile(
            typeCombinations: ProfileType.time | ProfileType.usageLimit,
          ),
        ).hasTimeCondition,
        isTrue,
      );
    });

    test('hasUsageLimit reflects ProfileType.usageLimit bit', () {
      expect(
        ProfileModel(
          data: buildProfile(typeCombinations: ProfileType.usageLimit),
        ).hasUsageLimit,
        isTrue,
      );
      expect(
        ProfileModel(
          data: buildProfile(typeCombinations: ProfileType.time),
        ).hasUsageLimit,
        isFalse,
      );
    });

    test('isQuickBlock reflects ProfileType.quickBlock bit', () {
      expect(
        ProfileModel(
          data: buildProfile(typeCombinations: ProfileType.quickBlock),
        ).isQuickBlock,
        isTrue,
      );
      expect(
        ProfileModel(
          data: buildProfile(typeCombinations: ProfileType.time),
        ).isQuickBlock,
        isFalse,
      );
    });
  });

  group('modeLabel', () {
    test('"Allowlist" for BlockingMode.allowlist', () {
      final model = ProfileModel(
        data: buildProfile(blockingMode: BlockingMode.allowlist),
      );
      expect(model.modeLabel, 'Allowlist');
    });

    test('"Blocklist" for BlockingMode.blocklist', () {
      final model = ProfileModel(
        data: buildProfile(blockingMode: BlockingMode.blocklist),
      );
      expect(model.modeLabel, 'Blocklist');
    });
  });

  group('dayFlagsLabel', () {
    test('"Every day" for allDays (127)', () {
      final model = ProfileModel(
        data: buildProfile(dayFlags: DayFlags.allDays),
      );
      expect(model.dayFlagsLabel, 'Every day');
    });

    test('"Weekdays" for weekdays (31)', () {
      final model = ProfileModel(
        data: buildProfile(dayFlags: DayFlags.weekdays),
      );
      expect(model.dayFlagsLabel, 'Weekdays');
    });

    test('"Weekend" for weekend (96)', () {
      final model = ProfileModel(
        data: buildProfile(dayFlags: DayFlags.weekend),
      );
      expect(model.dayFlagsLabel, 'Weekend');
    });

    test('"Mon, Wed, Fri" for monday | wednesday | friday', () {
      final flags =
          DayFlags.monday | DayFlags.wednesday | DayFlags.friday;
      final model = ProfileModel(data: buildProfile(dayFlags: flags));
      expect(model.dayFlagsLabel, 'Mon, Wed, Fri');
    });

    test('only a single day produces just that day name', () {
      final model = ProfileModel(
        data: buildProfile(dayFlags: DayFlags.thursday),
      );
      expect(model.dayFlagsLabel, 'Thu');
    });

    test('no days set yields empty label (edge case)', () {
      final model = ProfileModel(data: buildProfile(dayFlags: 0));
      expect(model.dayFlagsLabel, '');
    });
  });

  group('subtitle', () {
    test('default subtitle (no apps/sites/intervals) just has mode + 0 apps + days',
        () {
      final model = ProfileModel(data: buildProfile());
      expect(model.subtitle, 'Blocklist · 0 apps · Every day');
    });

    test('includes apps count', () {
      final model = ProfileModel(
        data: buildProfile(),
        apps: [
          buildAppRel(1, 'com.a'),
          buildAppRel(1, 'com.b'),
          buildAppRel(1, 'com.c'),
        ],
      );
      expect(model.subtitle, contains('3 apps'));
    });

    test('omits sites segment when websites is empty', () {
      final model = ProfileModel(data: buildProfile());
      expect(model.subtitle, isNot(contains('sites')));
    });

    test('includes sites count when websites is not empty', () {
      final model = ProfileModel(
        data: buildProfile(),
        websites: [
          buildWebsiteRule(1, 'reddit.com'),
          buildWebsiteRule(1, 'twitter.com'),
        ],
      );
      expect(model.subtitle, contains('2 sites'));
    });

    test(
        'omits intervals segment when typeCombinations has no time bit '
        '(even if intervals list is populated)', () {
      final model = ProfileModel(
        data: buildProfile(typeCombinations: 0),
        intervals: [buildInterval(1, 540, 1020)],
      );
      expect(model.subtitle, isNot(contains('09:00')));
    });

    test('includes interval formatted HH:MM - HH:MM when hasTimeCondition',
        () {
      final model = ProfileModel(
        data: buildProfile(typeCombinations: ProfileType.time),
        // 09:00 → 17:00 = 540 → 1020.
        intervals: [buildInterval(1, 540, 1020)],
      );
      expect(model.subtitle, contains('09:00 - 17:00'));
    });

    test('joins multiple intervals with ", "', () {
      final model = ProfileModel(
        data: buildProfile(typeCombinations: ProfileType.time),
        intervals: [
          buildInterval(1, 540, 720), // 09:00-12:00
          buildInterval(1, 840, 1020), // 14:00-17:00
        ],
      );
      expect(model.subtitle, contains('09:00 - 12:00, 14:00 - 17:00'));
    });

    test('subtitle terminates with dayFlagsLabel (separated by " \\u00b7 ")',
        () {
      final model = ProfileModel(
        data: buildProfile(
          blockingMode: BlockingMode.allowlist,
          dayFlags: DayFlags.weekdays,
          typeCombinations: ProfileType.time,
        ),
        apps: [buildAppRel(1, 'com.a')],
        websites: [buildWebsiteRule(1, 'foo.com')],
        intervals: [buildInterval(1, 540, 1020)],
      );
      expect(
        model.subtitle,
        'Allowlist · 1 apps · 1 sites · 09:00 - 17:00 · Weekdays',
      );
    });
  });

  group('_formatMinutes (verified through subtitle)', () {
    ProfileModel withInterval(int from, int to) => ProfileModel(
          data: buildProfile(typeCombinations: ProfileType.time),
          intervals: [buildInterval(1, from, to)],
        );

    test('0 → 00:00', () {
      expect(withInterval(0, 60).subtitle, contains('00:00 - 01:00'));
    });

    test('90 → 01:30', () {
      expect(withInterval(90, 120).subtitle, contains('01:30 - 02:00'));
    });

    test('1439 → 23:59 (one minute before midnight)', () {
      expect(withInterval(0, 1439).subtitle, contains('00:00 - 23:59'));
    });

    test('59 → 00:59', () {
      expect(withInterval(0, 59).subtitle, contains('00:00 - 00:59'));
    });

    test('cross-midnight pair (1320 → 360 = 22:00-06:00) still formats both sides',
        () {
      expect(withInterval(1320, 360).subtitle, contains('22:00 - 06:00'));
    });
  });
}
