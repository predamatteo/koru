import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/hive_keys.dart';

void main() {
  group('HiveKeys box names', () {
    final boxNames = <String>{
      HiveKeys.settingsBox,
      HiveKeys.onboardingBox,
      HiveKeys.uiStateBox,
      HiveKeys.cacheBox,
      HiveKeys.hiddenAppsBox,
      HiveKeys.quickTogglesBox,
    };

    test('there are exactly 6 unique box names', () {
      expect(boxNames.length, 6);
    });

    test('all box names start with "koru_" prefix', () {
      for (final name in boxNames) {
        expect(
          name.startsWith('koru_'),
          isTrue,
          reason: 'Box "$name" missing koru_ prefix',
        );
      }
    });

    test('exposes the documented literal values', () {
      expect(HiveKeys.settingsBox, 'koru_settings');
      expect(HiveKeys.onboardingBox, 'koru_onboarding');
      expect(HiveKeys.uiStateBox, 'koru_ui_state');
      expect(HiveKeys.cacheBox, 'koru_cache');
      expect(HiveKeys.hiddenAppsBox, 'koru_hidden_apps');
      expect(HiveKeys.quickTogglesBox, 'koru_quick_toggles');
    });
  });

  group('HiveKeys settings-box keys', () {
    final settingsKeys = <String>{
      HiveKeys.strictModeEnabled,
      HiveKeys.isLauncherDefault,
      HiveKeys.monochromeEnabled,
      HiveKeys.localeCode,
      HiveKeys.themeMode,
      HiveKeys.intentionsMode,
      HiveKeys.privacyPolicyAccepted,
      HiveKeys.accessibilityPrivacyAccepted,
      HiveKeys.focusSessionsCount,
      HiveKeys.lastMoodCheckInDay,
      HiveKeys.firstInstallTimestamp,
    };

    test('all settings keys are unique', () {
      // The Set literal above would dedupe; assert the size matches the
      // expected count to defend against future duplicates.
      expect(settingsKeys.length, 11);
    });

    test('STRICT_MODE_ENABLED, MONOCHROME_ENABLED, THEME_MODE literals', () {
      expect(HiveKeys.strictModeEnabled, 'STRICT_MODE_ENABLED');
      expect(HiveKeys.monochromeEnabled, 'MONOCHROME_ENABLED');
      expect(HiveKeys.themeMode, 'THEME_MODE');
    });

    test('every settings key matches SCREAMING_SNAKE_CASE', () {
      final pattern = RegExp(r'^[A-Z][A-Z0-9_]*$');
      for (final key in settingsKeys) {
        expect(
          pattern.hasMatch(key),
          isTrue,
          reason: 'Settings key "$key" is not SCREAMING_SNAKE_CASE',
        );
      }
    });
  });

  group('HiveKeys keys across all boxes', () {
    final allKeys = <String>{
      // settings
      HiveKeys.strictModeEnabled,
      HiveKeys.isLauncherDefault,
      HiveKeys.monochromeEnabled,
      HiveKeys.localeCode,
      HiveKeys.themeMode,
      HiveKeys.intentionsMode,
      HiveKeys.privacyPolicyAccepted,
      HiveKeys.accessibilityPrivacyAccepted,
      HiveKeys.focusSessionsCount,
      HiveKeys.lastMoodCheckInDay,
      HiveKeys.firstInstallTimestamp,
      // onboarding
      HiveKeys.isOnboardingPassed,
      HiveKeys.isPermissionsPassed,
      HiveKeys.isDemoPassed,
      HiveKeys.isPresetApplied,
      HiveKeys.isLauncherPromptShown,
      // ui_state
      HiveKeys.activeFontId,
      HiveKeys.activeColorSchemeId,
      HiveKeys.lastSeenDrawerLetter,
      HiveKeys.lastTabIndex,
      HiveKeys.coachmarksDismissed,
      HiveKeys.launcherLeftShortcut,
      HiveKeys.launcherRightShortcut,
      // cache
      HiveKeys.appIconCache,
      // hidden apps
      HiveKeys.hiddenApps,
      HiveKeys.renamedApps,
      // quick toggles
      HiveKeys.lastQuickBlockDurationMinutes,
      HiveKeys.lastPomodoroWorkMinutes,
      HiveKeys.lastPomodoroBreakMinutes,
      HiveKeys.lastPomodoroCycles,
    };

    test('every key is non-empty', () {
      for (final key in allKeys) {
        expect(key, isNotEmpty);
      }
    });

    test('every key follows SCREAMING_SNAKE_CASE', () {
      final pattern = RegExp(r'^[A-Z][A-Z0-9_]*$');
      for (final key in allKeys) {
        expect(
          pattern.hasMatch(key),
          isTrue,
          reason: 'Key "$key" is not SCREAMING_SNAKE_CASE',
        );
      }
    });

    test('keys do not collide with box names', () {
      final boxNames = <String>{
        HiveKeys.settingsBox,
        HiveKeys.onboardingBox,
        HiveKeys.uiStateBox,
        HiveKeys.cacheBox,
        HiveKeys.hiddenAppsBox,
        HiveKeys.quickTogglesBox,
      };
      expect(allKeys.intersection(boxNames), isEmpty);
    });
  });
}
