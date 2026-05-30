/// Constants for Hive box names and keys used across Koru.
///
/// Hive è usato per KV settings veloci e reattivi (config UI-state, onboarding
/// flags, quick toggles). Dati relazionali e analytics vanno su Drift.
class HiveKeys {
  const HiveKeys._();

  // ─── Box names ─────────────────────────────────────────────────────────────
  static const String settingsBox = 'koru_settings';
  static const String onboardingBox = 'koru_onboarding';
  static const String uiStateBox = 'koru_ui_state';
  static const String cacheBox = 'koru_cache';
  static const String hiddenAppsBox = 'koru_hidden_apps';
  static const String quickTogglesBox = 'koru_quick_toggles';

  // ─── settings box keys ─────────────────────────────────────────────────────
  static const String strictModeEnabled = 'STRICT_MODE_ENABLED';
  static const String isLauncherDefault = 'IS_LAUNCHER_DEFAULT';
  static const String monochromeEnabled = 'MONOCHROME_ENABLED';
  static const String localeCode = 'LOCALE_CODE';
  static const String themeMode = 'THEME_MODE';
  static const String intentionsMode = 'INTENTIONS_MODE';
  static const String privacyPolicyAccepted = 'PRIVACY_POLICY_ACCEPTED';
  static const String accessibilityPrivacyAccepted = 'ACCESSIBILITY_PRIVACY_ACCEPTED';
  static const String focusSessionsCount = 'FOCUS_SESSIONS_COUNT';
  static const String lastMoodCheckInDay = 'LAST_MOOD_CHECK_IN_DAY';
  static const String firstInstallTimestamp = 'FIRST_INSTALL_TIMESTAMP';

  // ─── onboarding box keys ───────────────────────────────────────────────────
  static const String isOnboardingPassed = 'IS_ONBOARDING_PASSED';
  static const String isPermissionsPassed = 'IS_PERMISSIONS_PASSED';
  static const String isDemoPassed = 'IS_DEMO_PASSED';
  static const String isPresetApplied = 'IS_PRESET_APPLIED';
  static const String isLauncherPromptShown = 'IS_LAUNCHER_PROMPT_SHOWN';

  // ─── ui_state box keys ─────────────────────────────────────────────────────
  static const String activeFontId = 'ACTIVE_FONT_ID';
  static const String activeColorSchemeId = 'ACTIVE_COLOR_SCHEME_ID';
  static const String lastSeenDrawerLetter = 'LAST_SEEN_DRAWER_LETTER';
  static const String lastTabIndex = 'LAST_TAB_INDEX';
  static const String coachmarksDismissed = 'COACHMARKS_DISMISSED';
  /// Package scelto dall'utente per shortcut sinistro del launcher (default: dialer).
  static const String launcherLeftShortcut = 'LAUNCHER_LEFT_SHORTCUT';
  /// Package scelto per shortcut destro del launcher (default: camera).
  static const String launcherRightShortcut = 'LAUNCHER_RIGHT_SHORTCUT';
  /// Azione swipe LATERALE del launcher (formato serializzato
  /// `LauncherSwipeAction`). Lo swipe verso l'alto è una gesture fissa su
  /// "All apps" e NON è persistito.
  /// Swipe verso sinistra — default: nessuna azione.
  static const String launcherSwipeLeft = 'LAUNCHER_SWIPE_LEFT';
  /// Swipe verso destra — default: nessuna azione.
  static const String launcherSwipeRight = 'LAUNCHER_SWIPE_RIGHT';

  // ─── cache box keys ────────────────────────────────────────────────────────
  /// Mappa packageName → icon base64, invalidata su install/uninstall events.
  static const String appIconCache = 'APP_ICON_CACHE';

  // ─── hidden_apps box keys ──────────────────────────────────────────────────
  /// `Set<String>` di package nascosti dal drawer (feature Phase 2 da MP).
  static const String hiddenApps = 'HIDDEN_APPS';
  static const String renamedApps = 'RENAMED_APPS';

  // ─── quick_toggles box keys ────────────────────────────────────────────────
  static const String lastQuickBlockDurationMinutes = 'LAST_QUICK_BLOCK_DURATION_MINUTES';
  static const String lastPomodoroWorkMinutes = 'LAST_POMODORO_WORK_MINUTES';
  static const String lastPomodoroBreakMinutes = 'LAST_POMODORO_BREAK_MINUTES';
  static const String lastPomodoroCycles = 'LAST_POMODORO_CYCLES';
}
