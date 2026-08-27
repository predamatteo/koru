// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Koru';

  @override
  String get appTagline =>
      'A minimalist launcher and mindful blocker to reclaim your attention.';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Koru';

  @override
  String get onboardingWelcomeSubtitle =>
      'Koru is a symbol of inner growth. Take back control of your attention, one breath at a time.';

  @override
  String get tabHome => 'Home';

  @override
  String get tabProfiles => 'Profiles';

  @override
  String get tabStats => 'Stats';

  @override
  String get tabSettings => 'Settings';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonBack => 'Back';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonOk => 'OK';

  @override
  String get commonEnable => 'Enable';

  @override
  String get commonDisable => 'Disable';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonDone => 'Done';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonAll => 'All';

  @override
  String get commonNone => 'None';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonSearchApps => 'Search apps';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get languageNativeNote =>
      'This also applies to the block overlay, notifications and the home screen widget. On Android 13 and later the choice is mirrored in Android Settings › Apps › Koru › Language.';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionLauncher => 'Launcher';

  @override
  String get settingsSectionDiscipline => 'Discipline';

  @override
  String get settingsSectionPermissions => 'Permissions';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsSectionEmergency => 'Emergency';

  @override
  String get settingsSetAsDefault => 'Set as default';

  @override
  String get settingsAppPersonalization => 'App personalization';

  @override
  String get permissionsTitle => 'Permissions';

  @override
  String get aboutTitle => 'About Koru';

  @override
  String get backdoorTitle => 'Emergency unlock';

  @override
  String get appLimitsTitle => 'App daily limits';

  @override
  String get notificationFilterTitle => 'Notification filter';

  @override
  String get unlockChallengeTitle => 'Unlock challenge';

  @override
  String get strictModeTitle => 'Strict mode';

  @override
  String get strictModeStatusOn => 'Strict mode is ON';

  @override
  String get strictModeStatusOff => 'Strict mode is OFF';

  @override
  String get strictModeDescriptionOn =>
      'Settings, Recents and Uninstall are locked. Loosening or turning it off means rebuilding a sequence of symbols — the backdoor code is only for emergencies.';

  @override
  String get strictModeDescriptionOff =>
      'Turn on to lock Settings, Recents and Uninstall. Requires Device Admin.';

  @override
  String get strictModeWhatToLock => 'What to lock';

  @override
  String get strictModeBlockSettings => 'Block Settings';

  @override
  String get strictModeBlockSettingsSubtitle =>
      'Prevents opening the Android Settings app.';

  @override
  String get strictModeBlockRecents => 'Block Recent apps';

  @override
  String get strictModeBlockRecentsSubtitle =>
      'Prevents opening the Recent apps view.';

  @override
  String get strictModeBlockUninstall => 'Block Uninstall';

  @override
  String get strictModeBlockUninstallSubtitle => 'Prevents uninstalling Koru.';

  @override
  String get strictModeDeviceAdmin => 'Device Admin';

  @override
  String get strictModeDeviceAdminActive => 'Device Admin active';

  @override
  String get strictModeDeviceAdminRequired => 'Device Admin required';

  @override
  String get strictModeDeviceAdminActiveSubtitle =>
      'Koru has the permissions it needs.';

  @override
  String get strictModeDeviceAdminRequiredSubtitle =>
      'Koru needs Device Admin to enforce Strict Mode.';

  @override
  String get strictModeVerificationExpired =>
      'The verification expired. Try again.';

  @override
  String get strictModeApplyFailed => 'The change could not be applied.';

  @override
  String get strictModeActionRemoveRestriction => 'remove this restriction';

  @override
  String get strictModeActionTurnOff => 'turn off strict mode';

  @override
  String get strictModeActiveDialogTitle => 'Strict mode is on';

  @override
  String get strictModeActiveDialogBody =>
      'To disable Device Admin you first have to turn off strict mode with the switch above.';

  @override
  String get aboutKoruBody =>
      'The Koru is the unfolding frond of a silver fern, a sacred Maori symbol of new life and inner growth. It reminds us that focus is not a constraint — it is a returning to ourselves.';

  @override
  String get aboutPrivacyTitle => 'Privacy';

  @override
  String get aboutPrivacyBody =>
      'Everything Koru does happens on your device. No accounts, no ads, no tracking. Ever.';

  @override
  String unlockChallengeActiveFriction(String level) {
    return 'Active friction: $level';
  }

  @override
  String get unlockChallengeExplainer =>
      'Turning a profile off, deleting it or taking apps away from it first asks you to memorise a short sequence of symbols and rebuild it in a grid full of lookalikes.\n\nIt exists to put a few seconds of clarity between the impulse and the tap. Turning a protection on is always immediate.\n\nYou choose how much friction, not whether to have it: a challenge you can switch off with one tap is exactly the tap you wanted to stop.';

  @override
  String get unlockChallengeHowMuchFriction => 'How much friction';

  @override
  String get unlockChallengeLevelGentle => 'Gentle';

  @override
  String get unlockChallengeLevelStandard => 'Standard';

  @override
  String get unlockChallengeLevelStubborn => 'Stubborn';

  @override
  String get unlockChallengeLevelGentleDesc =>
      '3 symbols, 5 seconds to memorise them.';

  @override
  String get unlockChallengeLevelStandardDesc =>
      '4 symbols, 4 seconds, more decoys.';

  @override
  String get unlockChallengeLevelStubbornDesc =>
      '5 symbols, 3 seconds, a grid full of lookalikes.';

  @override
  String get unlockChallengeTryNow => 'Try it now';

  @override
  String get unlockChallengeTryNowNote => 'A dry run: it turns nothing off.';

  @override
  String get unlockChallengeActionPreview => 'try the challenge';

  @override
  String get unlockChallengePreviewPassed =>
      'Passed. This is exactly what you will be asked.';

  @override
  String get unlockChallengePreviewCancelled => 'Run cancelled.';

  @override
  String get permissionsIntro =>
      'Koru only runs on your device. Nothing ever leaves it.';

  @override
  String get permRequiredBadge => 'Required';

  @override
  String get permGrant => 'Grant';

  @override
  String get permAccessibility => 'Accessibility';

  @override
  String get permAccessibilitySubtitle =>
      'Detect when you open a distracting app.';

  @override
  String get permUsageAccess => 'Usage access';

  @override
  String get permUsageAccessSubtitle => 'Read time spent per app.';

  @override
  String get permOverlay => 'Display over other apps';

  @override
  String get permOverlaySubtitle => 'Show the mindful overlay.';

  @override
  String get permBattery => 'Battery optimization';

  @override
  String get permBatterySubtitle =>
      'Keep the blocking engine alive in background.';

  @override
  String get permNotifications => 'Notifications';

  @override
  String get permNotificationsSubtitle =>
      'Let Koru warn you when blocking needs attention.';

  @override
  String get permNotificationListener => 'Notification listener';

  @override
  String get permNotificationListenerSubtitle =>
      'Filter notifications from blocked apps (Phase 2).';

  @override
  String get appLimitsIntro =>
      'Sorted by how long you used them today. Tap an app to set a daily minutes cap.';

  @override
  String get appLimitsNotUsedToday => 'Not used today';

  @override
  String appLimitsMinutesToday(int minutes) {
    return '$minutes min today';
  }

  @override
  String appLimitsHoursToday(int hours) {
    return '${hours}h today';
  }

  @override
  String appLimitsHoursMinutesToday(int hours, int minutes) {
    return '${hours}h ${minutes}m today';
  }

  @override
  String appLimitsUsedOfCap(int used, int cap) {
    return '$used / $cap min today';
  }

  @override
  String appLimitsBadgeMinutes(int minutes) {
    return '$minutes m';
  }

  @override
  String appLimitsPresetMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String get appLimitsDailyCap => 'Daily cap';

  @override
  String get appLimitsMinPerDay => 'min / day';

  @override
  String get appLimitsStrictTitle => 'Strict daily limit';

  @override
  String get appLimitsStrictOn => 'Hard cap. No \"Open anyway\" once reached.';

  @override
  String get appLimitsStrictOff =>
      'Bypass allowed, gets harder each time today.';

  @override
  String get appLimitsChallengeLockTitle => 'Challenge lock';

  @override
  String get appLimitsChallengeLockOn =>
      'The memory challenge is required to loosen the limit, and to open the app once the cap is reached.';

  @override
  String get appLimitsChallengeLockOff =>
      'No challenge: the limit changes in one tap.';

  @override
  String appLimitsActionLoosen(String app) {
    return 'loosen the limit for $app';
  }

  @override
  String get notificationFilterIntro =>
      'Notifications from the apps you silence will be dismissed before reaching the status bar.';

  @override
  String get notificationFilterAccessRequired => 'Notification access required';

  @override
  String get notificationFilterAccessRequiredSubtitle =>
      'Enable Koru in Notification access to make silencing effective.';

  @override
  String get backdoorCurrentWeeklyCode => 'Your current weekly code';

  @override
  String get backdoorCodeExplainer =>
      'Copy the code somewhere safe. It rotates every week, it is generated randomly on your device, it works offline, and every code is single-use: as soon as you use it to unlock strict mode it is replaced by a new one.';

  @override
  String get backdoorCodeUnavailable => 'Code temporarily unavailable';

  @override
  String get backdoorCodeUnavailableBody =>
      'The device\'s secure storage (Keystore) cannot be reached right now, so we cannot generate the weekly code. Try again shortly or restart the device.';

  @override
  String get backdoorUnblockSection => 'Emergency unblock';

  @override
  String get backdoorEnterCode => 'Enter the code';

  @override
  String get backdoorUnlockButton => 'Unlock';

  @override
  String backdoorAttemptsLeft(int count) {
    return '$count attempts left before lockout';
  }

  @override
  String get backdoorResultValid =>
      'Valid code — strict mode turned off. The code has been consumed; a new one will be generated.';

  @override
  String get backdoorResultInvalid => 'Invalid code.';

  @override
  String get backdoorResultReplay =>
      'Code already used. Wait for the weekly rotation to get a new one.';

  @override
  String backdoorLockoutMinutes(int minutes) {
    return 'Lockout: $minutes minutes left.';
  }

  @override
  String backdoorLockoutHours(int hours) {
    return 'Lockout: $hours hours left.';
  }

  @override
  String backdoorLockoutDays(int days) {
    return 'Lockout: $days days left.';
  }

  @override
  String backdoorError(String message) {
    return 'Error: $message';
  }

  @override
  String get launcherIsDefault => 'Koru is your default launcher';

  @override
  String get launcherIsNotDefault => 'Koru is not your default launcher';

  @override
  String get launcherMakeSelectable => 'Make Koru selectable as launcher';

  @override
  String get launcherMakeSelectableSubtitle =>
      'Enables the HOME activity. You still need to pick Koru in the system chooser.';

  @override
  String get launcherOpenSystemPicker => 'Open system launcher picker';

  @override
  String get launcherSwipeGestures => 'Swipe gestures';

  @override
  String get launcherSwipeGesturesSubtitle =>
      'Swipe up always opens All apps. Assign an action to the left and right home-screen swipes. Distracting apps (blocked or limited) are not selectable.';

  @override
  String get launcherSwipeLeft => 'Swipe left';

  @override
  String get launcherSwipeRight => 'Swipe right';

  @override
  String get launcherSwipeAppSearch => 'App search';

  @override
  String get launcherSwipeGenericApp => 'App';

  @override
  String get fontTitle => 'Font';

  @override
  String get fontPreviewPangram =>
      'The quick brown fox jumps over the lazy dog';

  @override
  String get personalizationIntro =>
      'Long-press an app to rename. Toggle the eye to hide it from the launcher drawer (the app stays installed).';

  @override
  String get personalizationCustomName => 'Custom name';

  @override
  String get personalizationCustomNameHint => 'Leave empty to reset';

  @override
  String get personalizationResetAll => 'Reset all';

  @override
  String get personalizationResetDialogTitle => 'Reset personalization?';

  @override
  String get personalizationResetDialogBody =>
      'All custom names will be removed and all hidden apps will become visible again.';

  @override
  String personalizationWasNamed(String label) {
    return 'was: $label';
  }

  @override
  String get allAppsTitle => 'All apps';

  @override
  String get dayMon => 'Mon';

  @override
  String get dayTue => 'Tue';

  @override
  String get dayWed => 'Wed';

  @override
  String get dayThu => 'Thu';

  @override
  String get dayFri => 'Fri';

  @override
  String get daySat => 'Sat';

  @override
  String get daySun => 'Sun';

  @override
  String get dayEveryDay => 'Every day';

  @override
  String get dayWeekdays => 'Weekdays';

  @override
  String get dayWeekend => 'Weekend';

  @override
  String get profileUntitled => 'Untitled';

  @override
  String get profileModeAllowlist => 'Allowlist';

  @override
  String get profileModeBlocklist => 'Blocklist';

  @override
  String profileAppsCount(int count) {
    return '$count apps';
  }

  @override
  String profileSitesCount(int count) {
    return '$count sites';
  }

  @override
  String get profilesNew => 'New';

  @override
  String get profilesAllDay => 'All day';

  @override
  String profilesAppsBlocked(int count) {
    return '$count apps blocked';
  }

  @override
  String profilesActionTurnOff(String title) {
    return 'turn off «$title»';
  }

  @override
  String get profilesEmptyTitle => 'No profiles yet';

  @override
  String get profilesEmptyBody =>
      'Tap + to create your first profile and pick when and which apps to block.';

  @override
  String get profileEditorNewTitle => 'New profile';

  @override
  String get profileEditorEditTitle => 'Edit profile';

  @override
  String get profileEditorNameHint => 'Profile name';

  @override
  String get profileEditorNameFirst => 'Name the profile first';

  @override
  String get profileEditorPickIcon => 'Pick an icon';

  @override
  String get profileEditorActionDeleteGeneric => 'delete the profile';

  @override
  String profileEditorActionDeleteNamed(String title) {
    return 'delete «$title»';
  }

  @override
  String get profileEditorSectionSchedule => 'Schedule';

  @override
  String get profileEditorStart => 'Start';

  @override
  String get profileEditorEnd => 'End';

  @override
  String get profileEditorRemoveTimeSlot => 'Remove time slot';

  @override
  String get profileEditorAddTimeSlot => 'Add time slot';

  @override
  String get profileEditorAllDayTitle => 'All day';

  @override
  String get profileEditorAllDaySubtitle =>
      'Active around the clock, 00:00 → 00:00';

  @override
  String get profileEditorSectionBlockedApps => 'Blocked apps';

  @override
  String get profileEditorAppsSelected => 'Apps selected';

  @override
  String get profileEditorConfigure => 'Configure';

  @override
  String get profileEditorSaveFirst => 'Save the profile first to pick apps.';

  @override
  String get profileEditorSectionInAppContent => 'In-app content';

  @override
  String get profileEditorSectionWebsites => 'Websites';

  @override
  String get profileEditorBlockedDomains => 'Blocked domains';

  @override
  String get profileEditorSectionOnlyOnWifi => 'Only on Wi-Fi';

  @override
  String get profileEditorWifiNoFilter =>
      'No filter. Profile activates regardless of network.';

  @override
  String get profileEditorWifiActiveOnlyOn => 'Profile active only on:';

  @override
  String get profileEditorAddCurrentWifi => 'Add current';

  @override
  String get profileEditorAddWifiByName => 'Add by name';

  @override
  String get profileEditorAddWifiTitle => 'Add Wi-Fi SSID';

  @override
  String get profileEditorAddWifiHint => 'e.g. Home_WiFi';

  @override
  String get profileEditorWifiSsidReadFailed =>
      'Could not read current SSID. Ensure Wi-Fi is on and location permission is granted.';

  @override
  String get websitesIntro =>
      'Block domains inside the browser URL bar. Works across Chrome, Firefox, Brave, Samsung and other supported browsers.';

  @override
  String get websitesDomainLabel => 'Domain';

  @override
  String get websitesDomainHint => 'e.g. instagram.com';

  @override
  String get websitesMatchAnywhere => 'Match anywhere in URL';

  @override
  String get websitesMatchAnywhereOn => 'Blocks any URL that contains the text';

  @override
  String get websitesMatchAnywhereOff => 'Exact domain match (with subdomains)';

  @override
  String get websitesEmpty => 'No websites blocked yet.';

  @override
  String get websitesRuleAnywhere => 'Anywhere in URL';

  @override
  String get websitesRuleDomain => 'Domain match';

  @override
  String get websitesActionRemove => 'remove a site from an active profile';

  @override
  String get blockedAppsSelectApps => 'Select apps';

  @override
  String get blockedAppsMostUsedThisWeek => 'Most used this week';

  @override
  String blockedAppsNoMatch(String query) {
    return 'No apps matching \"$query\"';
  }

  @override
  String get blockedAppsActionWeaken =>
      'reduce the protection of an active profile';

  @override
  String get sectionInstagramReels => 'Reels';

  @override
  String get sectionInstagramStories => 'Stories';

  @override
  String get sectionInstagramExplore => 'Explore';

  @override
  String get sectionYoutubeShorts => 'Shorts';

  @override
  String get inAppContentIntro =>
      'Block specific sections inside an app. If the whole app is already on this profile\'s blocklist, sections are redundant and disabled.';

  @override
  String get inAppContentFullyBlocked => 'Fully blocked';

  @override
  String get inAppContentAppFullyBlocked => 'App fully blocked';

  @override
  String get inAppContentSectionDisabled =>
      'Section blocking disabled: the app is fully blocked in this profile.';

  @override
  String overlayDesignerTitle(String app) {
    return 'Overlay · $app';
  }

  @override
  String get overlayDesignerBackground => 'Background';

  @override
  String get overlayDesignerMessage => 'Message';

  @override
  String get overlayDesignerTitleField => 'Title (optional)';

  @override
  String get overlayDesignerSubtitleField => 'Subtitle (optional)';

  @override
  String get overlayDesignerCountdown => 'Countdown';

  @override
  String overlayDesignerSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get overlayDesignerAllowOpen => 'Allow opening after countdown';

  @override
  String get overlayDesignerAllowOpenSubtitle =>
      'Show the \"Open anyway\" button when the countdown completes.';

  @override
  String get commonViewAll => 'View all';

  @override
  String get achievementsTitle => 'Achievements';

  @override
  String achievementsUnlockedOf(int total) {
    return '/ $total unlocked';
  }

  @override
  String get achievementCategoryDiscipline => 'Discipline';

  @override
  String get achievementCategorySetup => 'Setup';

  @override
  String get achievementCleanWeekTitle => 'Clean week';

  @override
  String get achievementCleanWeekDesc =>
      'Seven days without exceeding any daily limit.';

  @override
  String get achievementIntentions50Title => 'Mindful chooser';

  @override
  String get achievementIntentions50Desc =>
      'Log an intention 50 times on the block overlay.';

  @override
  String get achievementHonestBlock100Title => 'Honest block';

  @override
  String get achievementHonestBlock100Desc =>
      'Respect a block (no bypass) 100 times.';

  @override
  String get achievementFirstProfileTitle => 'First profile';

  @override
  String get achievementFirstProfileDesc =>
      'Create your first blocking profile.';

  @override
  String get achievementCuratedTitle => 'Curated';

  @override
  String get achievementCuratedDesc => 'Set daily limits on 3 or more apps.';

  @override
  String get achievementLockdownTitle => 'Lockdown';

  @override
  String get achievementLockdownDesc => 'Enable strict mode at least once.';

  @override
  String get achievementCustomizedTitle => 'Customized';

  @override
  String get achievementCustomizedDesc =>
      'Personalize the overlay for at least one app.';

  @override
  String get achievementUnlockedToast => 'Achievement unlocked';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMay => 'May';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dec';

  @override
  String get statsPeriodToday => 'Today';

  @override
  String get statsPeriodWeek => 'This week';

  @override
  String get statsYesterday => 'Yesterday';

  @override
  String get statsPreviousDay => 'Previous day';

  @override
  String get statsNextDay => 'Next day';

  @override
  String get statsWholeWeek => 'Whole week';

  @override
  String get statsScreenTime => 'Screen time';

  @override
  String get statsDailyBreakdown => 'Daily breakdown';

  @override
  String get statsTopApps => 'Top apps';

  @override
  String get statsInterventions => 'Interventions';

  @override
  String get statsTapADay => 'Tap a day to see its apps';

  @override
  String get statsNoUsageRecorded => 'No usage recorded';

  @override
  String get statsNoUsageThisDay => 'No usage recorded for this day.';

  @override
  String get statsNoUsageThisPeriod =>
      'No foreground usage recorded for this period.';

  @override
  String get statsNoBlocksYet => 'No blocks yet';

  @override
  String statsPercentRespected(int percent) {
    return '$percent% respected';
  }

  @override
  String statsPercentSkipped(int percent) {
    return '$percent% skipped';
  }

  @override
  String get statsRefYesterday => 'yesterday';

  @override
  String get statsRefDayBefore => 'the day before';

  @override
  String get statsRefLastWeek => 'last week';

  @override
  String statsNoDataFrom(String period) {
    return 'no data from $period';
  }

  @override
  String statsDeltaFrom(String delta, String period) {
    return '$delta% from $period';
  }

  @override
  String get homeGreetingNight => 'Still awake?';

  @override
  String get homeGreetingMorning => 'Good morning.';

  @override
  String get homeGreetingAfternoon => 'Good afternoon.';

  @override
  String get homeGreetingEvening => 'Good evening.';

  @override
  String get homeGreetingSubtitle =>
      'Take a breath. What do you want to focus on today?';

  @override
  String get homeActiveRightNow => 'Active right now';

  @override
  String get homeNoProfileActiveNow => 'No profile active now';

  @override
  String get homeCreateOneToStart => 'Create one to get started';

  @override
  String homeProfilesConfigured(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profiles configured',
      one: '$count profile configured',
    );
    return '$_temp0';
  }

  @override
  String get homeBlocksLabel => 'Blocks';

  @override
  String get todayLimitsHeader => 'Today\'s limits';

  @override
  String get todayLimitsEmptyTitle => 'No daily limits yet';

  @override
  String get todayLimitsEmptyBody =>
      'Cap how long you can spend in an app each day. Koru steps in when you reach it.';

  @override
  String get todayLimitsSetOne => 'Set a limit';

  @override
  String todayLimitsUsedOfCap(int used, int cap) {
    return '$used / $cap min';
  }

  @override
  String get a11yBannerTitle => 'Koru blocking is OFF';

  @override
  String get a11yBannerBody =>
      'The accessibility service was disabled by the system. Limits and profiles will not work until you re-enable it.';

  @override
  String get a11yBannerAction => 'Re-enable';

  @override
  String get favoritesFolderOptions => 'Folder options';

  @override
  String get favoritesRenameFolder => 'Rename folder';

  @override
  String get favoritesDeleteFolder => 'Delete folder';

  @override
  String get favoritesDeleteFolderSubtitle => 'Its apps return to the home';

  @override
  String favoritesFolderDeleted(String name) {
    return 'Deleted folder \"$name\"';
  }

  @override
  String get favoritesEmptyFolder => 'Empty folder';

  @override
  String get favoritesEmptyHint =>
      'Long-press an app in the drawer to add it here.';

  @override
  String allAppsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apps',
      one: '$count app',
    );
    return '$_temp0';
  }

  @override
  String get allAppsClearSearch => 'Clear search';

  @override
  String get allAppsNoMatch => 'No matching apps';

  @override
  String get appMenuOptions => 'App options';

  @override
  String get appMenuAddFavorite => 'Add to favorites';

  @override
  String get appMenuRemoveFavorite => 'Remove from favorites';

  @override
  String appMenuAddedFavoriteToast(String app) {
    return 'Added $app to favorites';
  }

  @override
  String appMenuRemovedFavoriteToast(String app) {
    return 'Removed $app from favorites';
  }

  @override
  String appMenuFavoritesFailed(String error) {
    return 'Favorites update failed: $error';
  }

  @override
  String get appMenuMoveToFolder => 'Move to folder…';

  @override
  String get appMenuRemoveFromFolder => 'Remove from folder';

  @override
  String appMenuMovedBackHome(String app) {
    return 'Moved $app back to home';
  }

  @override
  String get appMenuAppInfo => 'App info';

  @override
  String get appMenuUninstall => 'Uninstall';

  @override
  String appMenuUninstallFailed(String app, String error) {
    return 'Could not uninstall $app: $error';
  }

  @override
  String get appMenuStrictDialogTitle => 'Strict mode is on';

  @override
  String get appMenuStrictDialogBody =>
      'Uninstalling apps is blocked while strict mode protects uninstalling. Turn that option off in Strict mode settings to uninstall apps.';

  @override
  String folderMoveTitle(String app) {
    return 'Move \"$app\"';
  }

  @override
  String get folderMoveSubtitle => 'Choose a destination folder';

  @override
  String get folderNew => 'New folder…';

  @override
  String get folderNewTitle => 'New folder';

  @override
  String get folderNameHint => 'Folder name';

  @override
  String get launcherPhone => 'Phone';

  @override
  String get launcherCamera => 'Camera';

  @override
  String get launcherKoruDashboard => 'Koru dashboard';

  @override
  String get launcherOpenAppsReset => 'Open apps counter reset';

  @override
  String get launcherLeftShortcut => 'Left shortcut';

  @override
  String get launcherRightShortcut => 'Right shortcut';

  @override
  String get launcherResetToDefault => 'Reset to default';

  @override
  String get launcherShortcutReset => 'Shortcut reset to default';

  @override
  String get challengeIntroTitle => 'One moment';

  @override
  String get challengeIntroSubtitle => 'Before weakening the protection.';

  @override
  String challengeIntroBody(String action) {
    return 'To $action you first have to rebuild a sequence of symbols.';
  }

  @override
  String get challengeIntroHint =>
      'We show them for a few seconds, then you find them again in a grid full of near-identical symbols.';

  @override
  String get challengeShowSequence => 'Show me the sequence';

  @override
  String get challengeMemorizeTitle => 'Memorise';

  @override
  String get challengeMemorizeSubtitle =>
      'These symbols, in this order. Then they disappear.';

  @override
  String get challengeRecallTitle => 'Rebuild';

  @override
  String get challengeRecallSubtitle =>
      'Tap them in the same order. Watch out for the lookalikes.';

  @override
  String get challengeBlockedTitle => 'Not now';

  @override
  String get challengeExpiredMidway =>
      'The verification expired before you finished. You can start over.';

  @override
  String challengeFailedAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts went wrong. No rush.',
      one: 'One attempt went wrong. No rush.',
    );
    return '$_temp0';
  }

  @override
  String get challengeGiveUp => 'Never mind';

  @override
  String challengeCooldown(String time) {
    return 'Too many failed attempts in a row. Try again in $time.';
  }

  @override
  String get challengeStartFailed =>
      'The verification could not be started. Try again in a moment.';

  @override
  String get commonApply => 'Apply';

  @override
  String get onboardingWelcomeTagline => 'A Maori symbol of inner growth.';

  @override
  String get onboardingWelcomeBody =>
      'Koru is a minimalist launcher and a mindful blocker. It helps you take back your attention — one breath at a time.';

  @override
  String get onboardingLauncherTitle => 'Use Koru as your launcher';

  @override
  String get onboardingLauncherBody =>
      'Set Koru as your default home screen for the full minimalist experience. You can always change this later in Settings.';

  @override
  String get onboardingLauncherCta => 'Set Koru as default launcher';

  @override
  String get onboardingLauncherSkipHint =>
      'Or skip — Koru works great either way.';

  @override
  String get onboardingPresetsTitle => 'Quick start';

  @override
  String get onboardingPresetsBody =>
      'Tap a preset to create a ready-to-go profile. You can edit it later.';

  @override
  String get onboardingEnterKoru => 'Enter Koru';

  @override
  String get onboardingSkipForNow => 'Skip for now';

  @override
  String get overlayTakeABreath => 'Take a breath';

  @override
  String get overlayFocusModeActive => 'Focus mode is active';

  @override
  String get overlaySectionBlocked => 'Section blocked';

  @override
  String get overlayWebsiteBlocked => 'Website blocked';

  @override
  String overlayPausedBy(String profile) {
    return 'Paused by “$profile”';
  }

  @override
  String overlayOpenApp(String app) {
    return 'Open $app';
  }

  @override
  String overlayDontOpenApp(String app) {
    return 'Don\'t open $app';
  }

  @override
  String get overlayTapTimerToPause => 'Tap the timer to pause it';

  @override
  String get overlayPaused => 'Paused';

  @override
  String overlayCountdownSemantics(int seconds) {
    return 'Countdown: $seconds seconds remaining';
  }

  @override
  String usageLimitActionOpenBeyond(String app) {
    return 'open $app past today\'s limit';
  }

  @override
  String get reelsScrolledToday => 'Scrolled today';

  @override
  String reelsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'reels',
      one: 'reel',
    );
    return '$_temp0';
  }

  @override
  String get reelsNoneToday => 'None today';

  @override
  String reelsNoneTodayWithAverage(int average) {
    return 'None today — your average is $average';
  }

  @override
  String get reelsFirstDays => 'First days of tracking';

  @override
  String reelsOnAverage(int average) {
    return 'Right on your daily average ($average)';
  }

  @override
  String reelsMoreThanAverage(int delta, int average) {
    return '$delta more than your daily average ($average)';
  }

  @override
  String reelsFewerThanAverage(int delta, int average) {
    return '$delta fewer than your daily average ($average)';
  }
}
