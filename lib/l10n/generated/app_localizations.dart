import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Koru'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'A minimalist launcher and mindful blocker to reclaim your attention.'**
  String get appTagline;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Koru'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Koru is a symbol of inner growth. Take back control of your attention, one breath at a time.'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get tabProfiles;

  /// No description provided for @tabStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get tabStats;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get commonEnable;

  /// No description provided for @commonDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get commonDisable;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonSearchApps.
  ///
  /// In en, this message translates to:
  /// **'Search apps'**
  String get commonSearchApps;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// No description provided for @languageNativeNote.
  ///
  /// In en, this message translates to:
  /// **'This also applies to the block overlay, notifications and the home screen widget. On Android 13 and later the choice is mirrored in Android Settings › Apps › Koru › Language.'**
  String get languageNativeNote;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionLauncher.
  ///
  /// In en, this message translates to:
  /// **'Launcher'**
  String get settingsSectionLauncher;

  /// No description provided for @settingsSectionDiscipline.
  ///
  /// In en, this message translates to:
  /// **'Discipline'**
  String get settingsSectionDiscipline;

  /// No description provided for @settingsSectionPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get settingsSectionPermissions;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsSectionEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get settingsSectionEmergency;

  /// No description provided for @settingsSetAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get settingsSetAsDefault;

  /// No description provided for @settingsAppPersonalization.
  ///
  /// In en, this message translates to:
  /// **'App personalization'**
  String get settingsAppPersonalization;

  /// No description provided for @permissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissionsTitle;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Koru'**
  String get aboutTitle;

  /// No description provided for @backdoorTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency unlock'**
  String get backdoorTitle;

  /// No description provided for @appLimitsTitle.
  ///
  /// In en, this message translates to:
  /// **'App daily limits'**
  String get appLimitsTitle;

  /// No description provided for @notificationFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification filter'**
  String get notificationFilterTitle;

  /// No description provided for @unlockChallengeTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock challenge'**
  String get unlockChallengeTitle;

  /// No description provided for @strictModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Strict mode'**
  String get strictModeTitle;

  /// No description provided for @strictModeStatusOn.
  ///
  /// In en, this message translates to:
  /// **'Strict mode is ON'**
  String get strictModeStatusOn;

  /// No description provided for @strictModeStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Strict mode is OFF'**
  String get strictModeStatusOff;

  /// No description provided for @strictModeDescriptionOn.
  ///
  /// In en, this message translates to:
  /// **'Settings, Recents and Uninstall are locked. Loosening or turning it off means rebuilding a sequence of symbols — the backdoor code is only for emergencies.'**
  String get strictModeDescriptionOn;

  /// No description provided for @strictModeDescriptionOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on to lock Settings, Recents and Uninstall. Requires Device Admin.'**
  String get strictModeDescriptionOff;

  /// No description provided for @strictModeWhatToLock.
  ///
  /// In en, this message translates to:
  /// **'What to lock'**
  String get strictModeWhatToLock;

  /// No description provided for @strictModeBlockSettings.
  ///
  /// In en, this message translates to:
  /// **'Block Settings'**
  String get strictModeBlockSettings;

  /// No description provided for @strictModeBlockSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prevents opening the Android Settings app.'**
  String get strictModeBlockSettingsSubtitle;

  /// No description provided for @strictModeBlockRecents.
  ///
  /// In en, this message translates to:
  /// **'Block Recent apps'**
  String get strictModeBlockRecents;

  /// No description provided for @strictModeBlockRecentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prevents opening the Recent apps view.'**
  String get strictModeBlockRecentsSubtitle;

  /// No description provided for @strictModeBlockUninstall.
  ///
  /// In en, this message translates to:
  /// **'Block Uninstall'**
  String get strictModeBlockUninstall;

  /// No description provided for @strictModeBlockUninstallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prevents uninstalling Koru.'**
  String get strictModeBlockUninstallSubtitle;

  /// No description provided for @strictModeDeviceAdmin.
  ///
  /// In en, this message translates to:
  /// **'Device Admin'**
  String get strictModeDeviceAdmin;

  /// No description provided for @strictModeDeviceAdminActive.
  ///
  /// In en, this message translates to:
  /// **'Device Admin active'**
  String get strictModeDeviceAdminActive;

  /// No description provided for @strictModeDeviceAdminRequired.
  ///
  /// In en, this message translates to:
  /// **'Device Admin required'**
  String get strictModeDeviceAdminRequired;

  /// No description provided for @strictModeDeviceAdminActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Koru has the permissions it needs.'**
  String get strictModeDeviceAdminActiveSubtitle;

  /// No description provided for @strictModeDeviceAdminRequiredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Koru needs Device Admin to enforce Strict Mode.'**
  String get strictModeDeviceAdminRequiredSubtitle;

  /// No description provided for @strictModeVerificationExpired.
  ///
  /// In en, this message translates to:
  /// **'The verification expired. Try again.'**
  String get strictModeVerificationExpired;

  /// No description provided for @strictModeApplyFailed.
  ///
  /// In en, this message translates to:
  /// **'The change could not be applied.'**
  String get strictModeApplyFailed;

  /// No description provided for @strictModeActionRemoveRestriction.
  ///
  /// In en, this message translates to:
  /// **'remove this restriction'**
  String get strictModeActionRemoveRestriction;

  /// No description provided for @strictModeActionTurnOff.
  ///
  /// In en, this message translates to:
  /// **'turn off strict mode'**
  String get strictModeActionTurnOff;

  /// No description provided for @strictModeActiveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Strict mode is on'**
  String get strictModeActiveDialogTitle;

  /// No description provided for @strictModeActiveDialogBody.
  ///
  /// In en, this message translates to:
  /// **'To disable Device Admin you first have to turn off strict mode with the switch above.'**
  String get strictModeActiveDialogBody;

  /// No description provided for @aboutKoruBody.
  ///
  /// In en, this message translates to:
  /// **'The Koru is the unfolding frond of a silver fern, a sacred Maori symbol of new life and inner growth. It reminds us that focus is not a constraint — it is a returning to ourselves.'**
  String get aboutKoruBody;

  /// No description provided for @aboutPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get aboutPrivacyTitle;

  /// No description provided for @aboutPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Everything Koru does happens on your device. No accounts, no ads, no tracking. Ever.'**
  String get aboutPrivacyBody;

  /// No description provided for @unlockChallengeActiveFriction.
  ///
  /// In en, this message translates to:
  /// **'Active friction: {level}'**
  String unlockChallengeActiveFriction(String level);

  /// No description provided for @unlockChallengeExplainer.
  ///
  /// In en, this message translates to:
  /// **'Turning a profile off, deleting it or taking apps away from it first asks you to memorise a short sequence of symbols and rebuild it in a grid full of lookalikes.\n\nIt exists to put a few seconds of clarity between the impulse and the tap. Turning a protection on is always immediate.\n\nYou choose how much friction, not whether to have it: a challenge you can switch off with one tap is exactly the tap you wanted to stop.'**
  String get unlockChallengeExplainer;

  /// No description provided for @unlockChallengeHowMuchFriction.
  ///
  /// In en, this message translates to:
  /// **'How much friction'**
  String get unlockChallengeHowMuchFriction;

  /// No description provided for @unlockChallengeLevelGentle.
  ///
  /// In en, this message translates to:
  /// **'Gentle'**
  String get unlockChallengeLevelGentle;

  /// No description provided for @unlockChallengeLevelStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get unlockChallengeLevelStandard;

  /// No description provided for @unlockChallengeLevelStubborn.
  ///
  /// In en, this message translates to:
  /// **'Stubborn'**
  String get unlockChallengeLevelStubborn;

  /// No description provided for @unlockChallengeLevelGentleDesc.
  ///
  /// In en, this message translates to:
  /// **'3 symbols, 5 seconds to memorise them.'**
  String get unlockChallengeLevelGentleDesc;

  /// No description provided for @unlockChallengeLevelStandardDesc.
  ///
  /// In en, this message translates to:
  /// **'4 symbols, 4 seconds, more decoys.'**
  String get unlockChallengeLevelStandardDesc;

  /// No description provided for @unlockChallengeLevelStubbornDesc.
  ///
  /// In en, this message translates to:
  /// **'5 symbols, 3 seconds, a grid full of lookalikes.'**
  String get unlockChallengeLevelStubbornDesc;

  /// No description provided for @unlockChallengeTryNow.
  ///
  /// In en, this message translates to:
  /// **'Try it now'**
  String get unlockChallengeTryNow;

  /// No description provided for @unlockChallengeTryNowNote.
  ///
  /// In en, this message translates to:
  /// **'A dry run: it turns nothing off.'**
  String get unlockChallengeTryNowNote;

  /// No description provided for @unlockChallengeActionPreview.
  ///
  /// In en, this message translates to:
  /// **'try the challenge'**
  String get unlockChallengeActionPreview;

  /// No description provided for @unlockChallengePreviewPassed.
  ///
  /// In en, this message translates to:
  /// **'Passed. This is exactly what you will be asked.'**
  String get unlockChallengePreviewPassed;

  /// No description provided for @unlockChallengePreviewCancelled.
  ///
  /// In en, this message translates to:
  /// **'Run cancelled.'**
  String get unlockChallengePreviewCancelled;

  /// No description provided for @permissionsIntro.
  ///
  /// In en, this message translates to:
  /// **'Koru only runs on your device. Nothing ever leaves it.'**
  String get permissionsIntro;

  /// No description provided for @permRequiredBadge.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get permRequiredBadge;

  /// No description provided for @permGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get permGrant;

  /// No description provided for @permAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get permAccessibility;

  /// No description provided for @permAccessibilitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Detect when you open a distracting app.'**
  String get permAccessibilitySubtitle;

  /// No description provided for @permUsageAccess.
  ///
  /// In en, this message translates to:
  /// **'Usage access'**
  String get permUsageAccess;

  /// No description provided for @permUsageAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read time spent per app.'**
  String get permUsageAccessSubtitle;

  /// No description provided for @permOverlay.
  ///
  /// In en, this message translates to:
  /// **'Display over other apps'**
  String get permOverlay;

  /// No description provided for @permOverlaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the mindful overlay.'**
  String get permOverlaySubtitle;

  /// No description provided for @permBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization'**
  String get permBattery;

  /// No description provided for @permBatterySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep the blocking engine alive in background.'**
  String get permBatterySubtitle;

  /// No description provided for @permNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get permNotifications;

  /// No description provided for @permNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let Koru warn you when blocking needs attention.'**
  String get permNotificationsSubtitle;

  /// No description provided for @permNotificationListener.
  ///
  /// In en, this message translates to:
  /// **'Notification listener'**
  String get permNotificationListener;

  /// No description provided for @permNotificationListenerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Filter notifications from blocked apps (Phase 2).'**
  String get permNotificationListenerSubtitle;

  /// No description provided for @appLimitsIntro.
  ///
  /// In en, this message translates to:
  /// **'Sorted by how long you used them today. Tap an app to set a daily minutes cap.'**
  String get appLimitsIntro;

  /// No description provided for @appLimitsNotUsedToday.
  ///
  /// In en, this message translates to:
  /// **'Not used today'**
  String get appLimitsNotUsedToday;

  /// No description provided for @appLimitsMinutesToday.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min today'**
  String appLimitsMinutesToday(int minutes);

  /// No description provided for @appLimitsHoursToday.
  ///
  /// In en, this message translates to:
  /// **'{hours}h today'**
  String appLimitsHoursToday(int hours);

  /// No description provided for @appLimitsHoursMinutesToday.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m today'**
  String appLimitsHoursMinutesToday(int hours, int minutes);

  /// No description provided for @appLimitsUsedOfCap.
  ///
  /// In en, this message translates to:
  /// **'{used} / {cap} min today'**
  String appLimitsUsedOfCap(int used, int cap);

  /// No description provided for @appLimitsBadgeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} m'**
  String appLimitsBadgeMinutes(int minutes);

  /// No description provided for @appLimitsPresetMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String appLimitsPresetMinutes(int minutes);

  /// No description provided for @appLimitsDailyCap.
  ///
  /// In en, this message translates to:
  /// **'Daily cap'**
  String get appLimitsDailyCap;

  /// No description provided for @appLimitsMinPerDay.
  ///
  /// In en, this message translates to:
  /// **'min / day'**
  String get appLimitsMinPerDay;

  /// No description provided for @appLimitsStrictTitle.
  ///
  /// In en, this message translates to:
  /// **'Strict daily limit'**
  String get appLimitsStrictTitle;

  /// No description provided for @appLimitsStrictOn.
  ///
  /// In en, this message translates to:
  /// **'Hard cap. No \"Open anyway\" once reached.'**
  String get appLimitsStrictOn;

  /// No description provided for @appLimitsStrictOff.
  ///
  /// In en, this message translates to:
  /// **'Bypass allowed, gets harder each time today.'**
  String get appLimitsStrictOff;

  /// No description provided for @appLimitsChallengeLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Challenge lock'**
  String get appLimitsChallengeLockTitle;

  /// No description provided for @appLimitsChallengeLockOn.
  ///
  /// In en, this message translates to:
  /// **'The memory challenge is required to loosen the limit, and to open the app once the cap is reached.'**
  String get appLimitsChallengeLockOn;

  /// No description provided for @appLimitsChallengeLockOff.
  ///
  /// In en, this message translates to:
  /// **'No challenge: the limit changes in one tap.'**
  String get appLimitsChallengeLockOff;

  /// No description provided for @appLimitsActionLoosen.
  ///
  /// In en, this message translates to:
  /// **'loosen the limit for {app}'**
  String appLimitsActionLoosen(String app);

  /// No description provided for @notificationFilterIntro.
  ///
  /// In en, this message translates to:
  /// **'Notifications from the apps you silence will be dismissed before reaching the status bar.'**
  String get notificationFilterIntro;

  /// No description provided for @notificationFilterAccessRequired.
  ///
  /// In en, this message translates to:
  /// **'Notification access required'**
  String get notificationFilterAccessRequired;

  /// No description provided for @notificationFilterAccessRequiredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Koru in Notification access to make silencing effective.'**
  String get notificationFilterAccessRequiredSubtitle;

  /// No description provided for @backdoorCurrentWeeklyCode.
  ///
  /// In en, this message translates to:
  /// **'Your current weekly code'**
  String get backdoorCurrentWeeklyCode;

  /// No description provided for @backdoorCodeExplainer.
  ///
  /// In en, this message translates to:
  /// **'Copy the code somewhere safe. It rotates every week, it is generated randomly on your device, it works offline, and every code is single-use: as soon as you use it to unlock strict mode it is replaced by a new one.'**
  String get backdoorCodeExplainer;

  /// No description provided for @backdoorCodeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Code temporarily unavailable'**
  String get backdoorCodeUnavailable;

  /// No description provided for @backdoorCodeUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'The device\'s secure storage (Keystore) cannot be reached right now, so we cannot generate the weekly code. Try again shortly or restart the device.'**
  String get backdoorCodeUnavailableBody;

  /// No description provided for @backdoorUnblockSection.
  ///
  /// In en, this message translates to:
  /// **'Emergency unblock'**
  String get backdoorUnblockSection;

  /// No description provided for @backdoorEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get backdoorEnterCode;

  /// No description provided for @backdoorUnlockButton.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get backdoorUnlockButton;

  /// No description provided for @backdoorAttemptsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} attempts left before lockout'**
  String backdoorAttemptsLeft(int count);

  /// No description provided for @backdoorResultValid.
  ///
  /// In en, this message translates to:
  /// **'Valid code — strict mode turned off. The code has been consumed; a new one will be generated.'**
  String get backdoorResultValid;

  /// No description provided for @backdoorResultInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid code.'**
  String get backdoorResultInvalid;

  /// No description provided for @backdoorResultReplay.
  ///
  /// In en, this message translates to:
  /// **'Code already used. Wait for the weekly rotation to get a new one.'**
  String get backdoorResultReplay;

  /// No description provided for @backdoorLockoutMinutes.
  ///
  /// In en, this message translates to:
  /// **'Lockout: {minutes} minutes left.'**
  String backdoorLockoutMinutes(int minutes);

  /// No description provided for @backdoorLockoutHours.
  ///
  /// In en, this message translates to:
  /// **'Lockout: {hours} hours left.'**
  String backdoorLockoutHours(int hours);

  /// No description provided for @backdoorLockoutDays.
  ///
  /// In en, this message translates to:
  /// **'Lockout: {days} days left.'**
  String backdoorLockoutDays(int days);

  /// No description provided for @backdoorError.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String backdoorError(String message);

  /// No description provided for @launcherIsDefault.
  ///
  /// In en, this message translates to:
  /// **'Koru is your default launcher'**
  String get launcherIsDefault;

  /// No description provided for @launcherIsNotDefault.
  ///
  /// In en, this message translates to:
  /// **'Koru is not your default launcher'**
  String get launcherIsNotDefault;

  /// No description provided for @launcherMakeSelectable.
  ///
  /// In en, this message translates to:
  /// **'Make Koru selectable as launcher'**
  String get launcherMakeSelectable;

  /// No description provided for @launcherMakeSelectableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enables the HOME activity. You still need to pick Koru in the system chooser.'**
  String get launcherMakeSelectableSubtitle;

  /// No description provided for @launcherOpenSystemPicker.
  ///
  /// In en, this message translates to:
  /// **'Open system launcher picker'**
  String get launcherOpenSystemPicker;

  /// No description provided for @launcherSwipeGestures.
  ///
  /// In en, this message translates to:
  /// **'Swipe gestures'**
  String get launcherSwipeGestures;

  /// No description provided for @launcherSwipeGesturesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Swipe up always opens All apps. Assign an action to the left and right home-screen swipes. Distracting apps (blocked or limited) are not selectable.'**
  String get launcherSwipeGesturesSubtitle;

  /// No description provided for @launcherSwipeLeft.
  ///
  /// In en, this message translates to:
  /// **'Swipe left'**
  String get launcherSwipeLeft;

  /// No description provided for @launcherSwipeRight.
  ///
  /// In en, this message translates to:
  /// **'Swipe right'**
  String get launcherSwipeRight;

  /// No description provided for @launcherSwipeAppSearch.
  ///
  /// In en, this message translates to:
  /// **'App search'**
  String get launcherSwipeAppSearch;

  /// No description provided for @launcherSwipeGenericApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get launcherSwipeGenericApp;

  /// No description provided for @fontTitle.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get fontTitle;

  /// No description provided for @fontPreviewPangram.
  ///
  /// In en, this message translates to:
  /// **'The quick brown fox jumps over the lazy dog'**
  String get fontPreviewPangram;

  /// No description provided for @personalizationIntro.
  ///
  /// In en, this message translates to:
  /// **'Long-press an app to rename. Toggle the eye to hide it from the launcher drawer (the app stays installed).'**
  String get personalizationIntro;

  /// No description provided for @personalizationCustomName.
  ///
  /// In en, this message translates to:
  /// **'Custom name'**
  String get personalizationCustomName;

  /// No description provided for @personalizationCustomNameHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to reset'**
  String get personalizationCustomNameHint;

  /// No description provided for @personalizationResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all'**
  String get personalizationResetAll;

  /// No description provided for @personalizationResetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset personalization?'**
  String get personalizationResetDialogTitle;

  /// No description provided for @personalizationResetDialogBody.
  ///
  /// In en, this message translates to:
  /// **'All custom names will be removed and all hidden apps will become visible again.'**
  String get personalizationResetDialogBody;

  /// No description provided for @personalizationWasNamed.
  ///
  /// In en, this message translates to:
  /// **'was: {label}'**
  String personalizationWasNamed(String label);

  /// No description provided for @allAppsTitle.
  ///
  /// In en, this message translates to:
  /// **'All apps'**
  String get allAppsTitle;

  /// No description provided for @dayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get dayMon;

  /// No description provided for @dayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get dayTue;

  /// No description provided for @dayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get dayWed;

  /// No description provided for @dayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get dayThu;

  /// No description provided for @dayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get dayFri;

  /// No description provided for @daySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get daySat;

  /// No description provided for @daySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get daySun;

  /// No description provided for @dayEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get dayEveryDay;

  /// No description provided for @dayWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get dayWeekdays;

  /// No description provided for @dayWeekend.
  ///
  /// In en, this message translates to:
  /// **'Weekend'**
  String get dayWeekend;

  /// No description provided for @profileUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get profileUntitled;

  /// No description provided for @profileModeAllowlist.
  ///
  /// In en, this message translates to:
  /// **'Allowlist'**
  String get profileModeAllowlist;

  /// No description provided for @profileModeBlocklist.
  ///
  /// In en, this message translates to:
  /// **'Blocklist'**
  String get profileModeBlocklist;

  /// No description provided for @profileAppsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} apps'**
  String profileAppsCount(int count);

  /// No description provided for @profileSitesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sites'**
  String profileSitesCount(int count);

  /// No description provided for @profilesNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get profilesNew;

  /// No description provided for @profilesAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get profilesAllDay;

  /// No description provided for @profilesAppsBlocked.
  ///
  /// In en, this message translates to:
  /// **'{count} apps blocked'**
  String profilesAppsBlocked(int count);

  /// No description provided for @profilesActionTurnOff.
  ///
  /// In en, this message translates to:
  /// **'turn off «{title}»'**
  String profilesActionTurnOff(String title);

  /// No description provided for @profilesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No profiles yet'**
  String get profilesEmptyTitle;

  /// No description provided for @profilesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create your first profile and pick when and which apps to block.'**
  String get profilesEmptyBody;

  /// No description provided for @profileEditorNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get profileEditorNewTitle;

  /// No description provided for @profileEditorEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditorEditTitle;

  /// No description provided for @profileEditorNameHint.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get profileEditorNameHint;

  /// No description provided for @profileEditorNameFirst.
  ///
  /// In en, this message translates to:
  /// **'Name the profile first'**
  String get profileEditorNameFirst;

  /// No description provided for @profileEditorPickIcon.
  ///
  /// In en, this message translates to:
  /// **'Pick an icon'**
  String get profileEditorPickIcon;

  /// No description provided for @profileEditorActionDeleteGeneric.
  ///
  /// In en, this message translates to:
  /// **'delete the profile'**
  String get profileEditorActionDeleteGeneric;

  /// No description provided for @profileEditorActionDeleteNamed.
  ///
  /// In en, this message translates to:
  /// **'delete «{title}»'**
  String profileEditorActionDeleteNamed(String title);

  /// No description provided for @profileEditorSectionSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get profileEditorSectionSchedule;

  /// No description provided for @profileEditorStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get profileEditorStart;

  /// No description provided for @profileEditorEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get profileEditorEnd;

  /// No description provided for @profileEditorRemoveTimeSlot.
  ///
  /// In en, this message translates to:
  /// **'Remove time slot'**
  String get profileEditorRemoveTimeSlot;

  /// No description provided for @profileEditorAddTimeSlot.
  ///
  /// In en, this message translates to:
  /// **'Add time slot'**
  String get profileEditorAddTimeSlot;

  /// No description provided for @profileEditorAllDayTitle.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get profileEditorAllDayTitle;

  /// No description provided for @profileEditorAllDaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Active around the clock, 00:00 → 00:00'**
  String get profileEditorAllDaySubtitle;

  /// No description provided for @profileEditorSectionBlockedApps.
  ///
  /// In en, this message translates to:
  /// **'Blocked apps'**
  String get profileEditorSectionBlockedApps;

  /// No description provided for @profileEditorAppsSelected.
  ///
  /// In en, this message translates to:
  /// **'Apps selected'**
  String get profileEditorAppsSelected;

  /// No description provided for @profileEditorConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get profileEditorConfigure;

  /// No description provided for @profileEditorSaveFirst.
  ///
  /// In en, this message translates to:
  /// **'Save the profile first to pick apps.'**
  String get profileEditorSaveFirst;

  /// No description provided for @profileEditorSectionInAppContent.
  ///
  /// In en, this message translates to:
  /// **'In-app content'**
  String get profileEditorSectionInAppContent;

  /// No description provided for @profileEditorSectionWebsites.
  ///
  /// In en, this message translates to:
  /// **'Websites'**
  String get profileEditorSectionWebsites;

  /// No description provided for @profileEditorBlockedDomains.
  ///
  /// In en, this message translates to:
  /// **'Blocked domains'**
  String get profileEditorBlockedDomains;

  /// No description provided for @profileEditorSectionOnlyOnWifi.
  ///
  /// In en, this message translates to:
  /// **'Only on Wi-Fi'**
  String get profileEditorSectionOnlyOnWifi;

  /// No description provided for @profileEditorWifiNoFilter.
  ///
  /// In en, this message translates to:
  /// **'No filter. Profile activates regardless of network.'**
  String get profileEditorWifiNoFilter;

  /// No description provided for @profileEditorWifiActiveOnlyOn.
  ///
  /// In en, this message translates to:
  /// **'Profile active only on:'**
  String get profileEditorWifiActiveOnlyOn;

  /// No description provided for @profileEditorAddCurrentWifi.
  ///
  /// In en, this message translates to:
  /// **'Add current'**
  String get profileEditorAddCurrentWifi;

  /// No description provided for @profileEditorAddWifiByName.
  ///
  /// In en, this message translates to:
  /// **'Add by name'**
  String get profileEditorAddWifiByName;

  /// No description provided for @profileEditorAddWifiTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Wi-Fi SSID'**
  String get profileEditorAddWifiTitle;

  /// No description provided for @profileEditorAddWifiHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Home_WiFi'**
  String get profileEditorAddWifiHint;

  /// No description provided for @profileEditorWifiSsidReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read current SSID. Ensure Wi-Fi is on and location permission is granted.'**
  String get profileEditorWifiSsidReadFailed;

  /// No description provided for @websitesIntro.
  ///
  /// In en, this message translates to:
  /// **'Block domains inside the browser URL bar. Works across Chrome, Firefox, Brave, Samsung and other supported browsers.'**
  String get websitesIntro;

  /// No description provided for @websitesDomainLabel.
  ///
  /// In en, this message translates to:
  /// **'Domain'**
  String get websitesDomainLabel;

  /// No description provided for @websitesDomainHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. instagram.com'**
  String get websitesDomainHint;

  /// No description provided for @websitesMatchAnywhere.
  ///
  /// In en, this message translates to:
  /// **'Match anywhere in URL'**
  String get websitesMatchAnywhere;

  /// No description provided for @websitesMatchAnywhereOn.
  ///
  /// In en, this message translates to:
  /// **'Blocks any URL that contains the text'**
  String get websitesMatchAnywhereOn;

  /// No description provided for @websitesMatchAnywhereOff.
  ///
  /// In en, this message translates to:
  /// **'Exact domain match (with subdomains)'**
  String get websitesMatchAnywhereOff;

  /// No description provided for @websitesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No websites blocked yet.'**
  String get websitesEmpty;

  /// No description provided for @websitesRuleAnywhere.
  ///
  /// In en, this message translates to:
  /// **'Anywhere in URL'**
  String get websitesRuleAnywhere;

  /// No description provided for @websitesRuleDomain.
  ///
  /// In en, this message translates to:
  /// **'Domain match'**
  String get websitesRuleDomain;

  /// No description provided for @websitesActionRemove.
  ///
  /// In en, this message translates to:
  /// **'remove a site from an active profile'**
  String get websitesActionRemove;

  /// No description provided for @blockedAppsSelectApps.
  ///
  /// In en, this message translates to:
  /// **'Select apps'**
  String get blockedAppsSelectApps;

  /// No description provided for @blockedAppsMostUsedThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Most used this week'**
  String get blockedAppsMostUsedThisWeek;

  /// No description provided for @blockedAppsNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No apps matching \"{query}\"'**
  String blockedAppsNoMatch(String query);

  /// No description provided for @blockedAppsActionWeaken.
  ///
  /// In en, this message translates to:
  /// **'reduce the protection of an active profile'**
  String get blockedAppsActionWeaken;

  /// No description provided for @sectionInstagramReels.
  ///
  /// In en, this message translates to:
  /// **'Reels'**
  String get sectionInstagramReels;

  /// No description provided for @sectionInstagramStories.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get sectionInstagramStories;

  /// No description provided for @sectionInstagramExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get sectionInstagramExplore;

  /// No description provided for @sectionYoutubeShorts.
  ///
  /// In en, this message translates to:
  /// **'Shorts'**
  String get sectionYoutubeShorts;

  /// No description provided for @inAppContentIntro.
  ///
  /// In en, this message translates to:
  /// **'Block specific sections inside an app. If the whole app is already on this profile\'s blocklist, sections are redundant and disabled.'**
  String get inAppContentIntro;

  /// No description provided for @inAppContentFullyBlocked.
  ///
  /// In en, this message translates to:
  /// **'Fully blocked'**
  String get inAppContentFullyBlocked;

  /// No description provided for @inAppContentAppFullyBlocked.
  ///
  /// In en, this message translates to:
  /// **'App fully blocked'**
  String get inAppContentAppFullyBlocked;

  /// No description provided for @inAppContentSectionDisabled.
  ///
  /// In en, this message translates to:
  /// **'Section blocking disabled: the app is fully blocked in this profile.'**
  String get inAppContentSectionDisabled;

  /// No description provided for @overlayDesignerTitle.
  ///
  /// In en, this message translates to:
  /// **'Overlay · {app}'**
  String overlayDesignerTitle(String app);

  /// No description provided for @overlayDesignerBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get overlayDesignerBackground;

  /// No description provided for @overlayDesignerMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get overlayDesignerMessage;

  /// No description provided for @overlayDesignerTitleField.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get overlayDesignerTitleField;

  /// No description provided for @overlayDesignerSubtitleField.
  ///
  /// In en, this message translates to:
  /// **'Subtitle (optional)'**
  String get overlayDesignerSubtitleField;

  /// No description provided for @overlayDesignerCountdown.
  ///
  /// In en, this message translates to:
  /// **'Countdown'**
  String get overlayDesignerCountdown;

  /// No description provided for @overlayDesignerSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String overlayDesignerSeconds(int seconds);

  /// No description provided for @overlayDesignerAllowOpen.
  ///
  /// In en, this message translates to:
  /// **'Allow opening after countdown'**
  String get overlayDesignerAllowOpen;

  /// No description provided for @overlayDesignerAllowOpenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the \"Open anyway\" button when the countdown completes.'**
  String get overlayDesignerAllowOpenSubtitle;

  /// No description provided for @commonViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get commonViewAll;

  /// No description provided for @achievementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievementsTitle;

  /// No description provided for @achievementsUnlockedOf.
  ///
  /// In en, this message translates to:
  /// **'/ {total} unlocked'**
  String achievementsUnlockedOf(int total);

  /// No description provided for @achievementCategoryDiscipline.
  ///
  /// In en, this message translates to:
  /// **'Discipline'**
  String get achievementCategoryDiscipline;

  /// No description provided for @achievementCategorySetup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get achievementCategorySetup;

  /// No description provided for @achievementCleanWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'Clean week'**
  String get achievementCleanWeekTitle;

  /// No description provided for @achievementCleanWeekDesc.
  ///
  /// In en, this message translates to:
  /// **'Seven days without exceeding any daily limit.'**
  String get achievementCleanWeekDesc;

  /// No description provided for @achievementIntentions50Title.
  ///
  /// In en, this message translates to:
  /// **'Mindful chooser'**
  String get achievementIntentions50Title;

  /// No description provided for @achievementIntentions50Desc.
  ///
  /// In en, this message translates to:
  /// **'Log an intention 50 times on the block overlay.'**
  String get achievementIntentions50Desc;

  /// No description provided for @achievementHonestBlock100Title.
  ///
  /// In en, this message translates to:
  /// **'Honest block'**
  String get achievementHonestBlock100Title;

  /// No description provided for @achievementHonestBlock100Desc.
  ///
  /// In en, this message translates to:
  /// **'Respect a block (no bypass) 100 times.'**
  String get achievementHonestBlock100Desc;

  /// No description provided for @achievementFirstProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'First profile'**
  String get achievementFirstProfileTitle;

  /// No description provided for @achievementFirstProfileDesc.
  ///
  /// In en, this message translates to:
  /// **'Create your first blocking profile.'**
  String get achievementFirstProfileDesc;

  /// No description provided for @achievementCuratedTitle.
  ///
  /// In en, this message translates to:
  /// **'Curated'**
  String get achievementCuratedTitle;

  /// No description provided for @achievementCuratedDesc.
  ///
  /// In en, this message translates to:
  /// **'Set daily limits on 3 or more apps.'**
  String get achievementCuratedDesc;

  /// No description provided for @achievementLockdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Lockdown'**
  String get achievementLockdownTitle;

  /// No description provided for @achievementLockdownDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable strict mode at least once.'**
  String get achievementLockdownDesc;

  /// No description provided for @achievementCustomizedTitle.
  ///
  /// In en, this message translates to:
  /// **'Customized'**
  String get achievementCustomizedTitle;

  /// No description provided for @achievementCustomizedDesc.
  ///
  /// In en, this message translates to:
  /// **'Personalize the overlay for at least one app.'**
  String get achievementCustomizedDesc;

  /// No description provided for @achievementUnlockedToast.
  ///
  /// In en, this message translates to:
  /// **'Achievement unlocked'**
  String get achievementUnlockedToast;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @monthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthJan;

  /// No description provided for @monthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthFeb;

  /// No description provided for @monthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthMar;

  /// No description provided for @monthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthApr;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthJun;

  /// No description provided for @monthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthJul;

  /// No description provided for @monthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthAug;

  /// No description provided for @monthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthSep;

  /// No description provided for @monthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthOct;

  /// No description provided for @monthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthNov;

  /// No description provided for @monthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthDec;

  /// No description provided for @statsPeriodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get statsPeriodToday;

  /// No description provided for @statsPeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get statsPeriodWeek;

  /// No description provided for @statsYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get statsYesterday;

  /// No description provided for @statsPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get statsPreviousDay;

  /// No description provided for @statsNextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get statsNextDay;

  /// No description provided for @statsWholeWeek.
  ///
  /// In en, this message translates to:
  /// **'Whole week'**
  String get statsWholeWeek;

  /// No description provided for @statsScreenTime.
  ///
  /// In en, this message translates to:
  /// **'Screen time'**
  String get statsScreenTime;

  /// No description provided for @statsDailyBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Daily breakdown'**
  String get statsDailyBreakdown;

  /// No description provided for @statsTopApps.
  ///
  /// In en, this message translates to:
  /// **'Top apps'**
  String get statsTopApps;

  /// No description provided for @statsInterventions.
  ///
  /// In en, this message translates to:
  /// **'Interventions'**
  String get statsInterventions;

  /// No description provided for @statsTapADay.
  ///
  /// In en, this message translates to:
  /// **'Tap a day to see its apps'**
  String get statsTapADay;

  /// No description provided for @statsNoUsageRecorded.
  ///
  /// In en, this message translates to:
  /// **'No usage recorded'**
  String get statsNoUsageRecorded;

  /// No description provided for @statsNoUsageThisDay.
  ///
  /// In en, this message translates to:
  /// **'No usage recorded for this day.'**
  String get statsNoUsageThisDay;

  /// No description provided for @statsNoUsageThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'No foreground usage recorded for this period.'**
  String get statsNoUsageThisPeriod;

  /// No description provided for @statsNoBlocksYet.
  ///
  /// In en, this message translates to:
  /// **'No blocks yet'**
  String get statsNoBlocksYet;

  /// No description provided for @statsPercentRespected.
  ///
  /// In en, this message translates to:
  /// **'{percent}% respected'**
  String statsPercentRespected(int percent);

  /// No description provided for @statsPercentSkipped.
  ///
  /// In en, this message translates to:
  /// **'{percent}% skipped'**
  String statsPercentSkipped(int percent);

  /// No description provided for @statsRefYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get statsRefYesterday;

  /// No description provided for @statsRefDayBefore.
  ///
  /// In en, this message translates to:
  /// **'the day before'**
  String get statsRefDayBefore;

  /// No description provided for @statsRefLastWeek.
  ///
  /// In en, this message translates to:
  /// **'last week'**
  String get statsRefLastWeek;

  /// No description provided for @statsNoDataFrom.
  ///
  /// In en, this message translates to:
  /// **'no data from {period}'**
  String statsNoDataFrom(String period);

  /// No description provided for @statsDeltaFrom.
  ///
  /// In en, this message translates to:
  /// **'{delta}% from {period}'**
  String statsDeltaFrom(String delta, String period);

  /// No description provided for @homeGreetingNight.
  ///
  /// In en, this message translates to:
  /// **'Still awake?'**
  String get homeGreetingNight;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning.'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon.'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening.'**
  String get homeGreetingEvening;

  /// No description provided for @homeGreetingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take a breath. What do you want to focus on today?'**
  String get homeGreetingSubtitle;

  /// No description provided for @homeActiveRightNow.
  ///
  /// In en, this message translates to:
  /// **'Active right now'**
  String get homeActiveRightNow;

  /// No description provided for @homeNoProfileActiveNow.
  ///
  /// In en, this message translates to:
  /// **'No profile active now'**
  String get homeNoProfileActiveNow;

  /// No description provided for @homeCreateOneToStart.
  ///
  /// In en, this message translates to:
  /// **'Create one to get started'**
  String get homeCreateOneToStart;

  /// No description provided for @homeProfilesConfigured.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} profile configured} other{{count} profiles configured}}'**
  String homeProfilesConfigured(int count);

  /// No description provided for @homeBlocksLabel.
  ///
  /// In en, this message translates to:
  /// **'Blocks'**
  String get homeBlocksLabel;

  /// No description provided for @todayLimitsHeader.
  ///
  /// In en, this message translates to:
  /// **'Today\'s limits'**
  String get todayLimitsHeader;

  /// No description provided for @todayLimitsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No daily limits yet'**
  String get todayLimitsEmptyTitle;

  /// No description provided for @todayLimitsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Cap how long you can spend in an app each day. Koru steps in when you reach it.'**
  String get todayLimitsEmptyBody;

  /// No description provided for @todayLimitsSetOne.
  ///
  /// In en, this message translates to:
  /// **'Set a limit'**
  String get todayLimitsSetOne;

  /// No description provided for @todayLimitsUsedOfCap.
  ///
  /// In en, this message translates to:
  /// **'{used} / {cap} min'**
  String todayLimitsUsedOfCap(int used, int cap);

  /// No description provided for @a11yBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Koru blocking is OFF'**
  String get a11yBannerTitle;

  /// No description provided for @a11yBannerBody.
  ///
  /// In en, this message translates to:
  /// **'The accessibility service was disabled by the system. Limits and profiles will not work until you re-enable it.'**
  String get a11yBannerBody;

  /// No description provided for @a11yBannerAction.
  ///
  /// In en, this message translates to:
  /// **'Re-enable'**
  String get a11yBannerAction;

  /// No description provided for @favoritesFolderOptions.
  ///
  /// In en, this message translates to:
  /// **'Folder options'**
  String get favoritesFolderOptions;

  /// No description provided for @favoritesRenameFolder.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get favoritesRenameFolder;

  /// No description provided for @favoritesDeleteFolder.
  ///
  /// In en, this message translates to:
  /// **'Delete folder'**
  String get favoritesDeleteFolder;

  /// No description provided for @favoritesDeleteFolderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Its apps return to the home'**
  String get favoritesDeleteFolderSubtitle;

  /// No description provided for @favoritesFolderDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted folder \"{name}\"'**
  String favoritesFolderDeleted(String name);

  /// No description provided for @favoritesEmptyFolder.
  ///
  /// In en, this message translates to:
  /// **'Empty folder'**
  String get favoritesEmptyFolder;

  /// No description provided for @favoritesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press an app in the drawer to add it here.'**
  String get favoritesEmptyHint;

  /// No description provided for @allAppsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} app} other{{count} apps}}'**
  String allAppsCount(int count);

  /// No description provided for @allAppsClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get allAppsClearSearch;

  /// No description provided for @allAppsNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching apps'**
  String get allAppsNoMatch;

  /// No description provided for @appMenuOptions.
  ///
  /// In en, this message translates to:
  /// **'App options'**
  String get appMenuOptions;

  /// No description provided for @appMenuAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get appMenuAddFavorite;

  /// No description provided for @appMenuRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get appMenuRemoveFavorite;

  /// No description provided for @appMenuAddedFavoriteToast.
  ///
  /// In en, this message translates to:
  /// **'Added {app} to favorites'**
  String appMenuAddedFavoriteToast(String app);

  /// No description provided for @appMenuRemovedFavoriteToast.
  ///
  /// In en, this message translates to:
  /// **'Removed {app} from favorites'**
  String appMenuRemovedFavoriteToast(String app);

  /// No description provided for @appMenuFavoritesFailed.
  ///
  /// In en, this message translates to:
  /// **'Favorites update failed: {error}'**
  String appMenuFavoritesFailed(String error);

  /// No description provided for @appMenuMoveToFolder.
  ///
  /// In en, this message translates to:
  /// **'Move to folder…'**
  String get appMenuMoveToFolder;

  /// No description provided for @appMenuRemoveFromFolder.
  ///
  /// In en, this message translates to:
  /// **'Remove from folder'**
  String get appMenuRemoveFromFolder;

  /// No description provided for @appMenuMovedBackHome.
  ///
  /// In en, this message translates to:
  /// **'Moved {app} back to home'**
  String appMenuMovedBackHome(String app);

  /// No description provided for @appMenuAppInfo.
  ///
  /// In en, this message translates to:
  /// **'App info'**
  String get appMenuAppInfo;

  /// No description provided for @appMenuUninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get appMenuUninstall;

  /// No description provided for @appMenuUninstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not uninstall {app}: {error}'**
  String appMenuUninstallFailed(String app, String error);

  /// No description provided for @appMenuStrictDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Strict mode is on'**
  String get appMenuStrictDialogTitle;

  /// No description provided for @appMenuStrictDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Uninstalling apps is blocked while strict mode protects uninstalling. Turn that option off in Strict mode settings to uninstall apps.'**
  String get appMenuStrictDialogBody;

  /// No description provided for @folderMoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Move \"{app}\"'**
  String folderMoveTitle(String app);

  /// No description provided for @folderMoveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a destination folder'**
  String get folderMoveSubtitle;

  /// No description provided for @folderNew.
  ///
  /// In en, this message translates to:
  /// **'New folder…'**
  String get folderNew;

  /// No description provided for @folderNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get folderNewTitle;

  /// No description provided for @folderNameHint.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderNameHint;

  /// No description provided for @launcherPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get launcherPhone;

  /// No description provided for @launcherCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get launcherCamera;

  /// No description provided for @launcherKoruDashboard.
  ///
  /// In en, this message translates to:
  /// **'Koru dashboard'**
  String get launcherKoruDashboard;

  /// No description provided for @launcherOpenAppsReset.
  ///
  /// In en, this message translates to:
  /// **'Open apps counter reset'**
  String get launcherOpenAppsReset;

  /// No description provided for @launcherLeftShortcut.
  ///
  /// In en, this message translates to:
  /// **'Left shortcut'**
  String get launcherLeftShortcut;

  /// No description provided for @launcherRightShortcut.
  ///
  /// In en, this message translates to:
  /// **'Right shortcut'**
  String get launcherRightShortcut;

  /// No description provided for @launcherResetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get launcherResetToDefault;

  /// No description provided for @launcherShortcutReset.
  ///
  /// In en, this message translates to:
  /// **'Shortcut reset to default'**
  String get launcherShortcutReset;

  /// No description provided for @challengeIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'One moment'**
  String get challengeIntroTitle;

  /// No description provided for @challengeIntroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Before weakening the protection.'**
  String get challengeIntroSubtitle;

  /// No description provided for @challengeIntroBody.
  ///
  /// In en, this message translates to:
  /// **'To {action} you first have to rebuild a sequence of symbols.'**
  String challengeIntroBody(String action);

  /// No description provided for @challengeIntroHint.
  ///
  /// In en, this message translates to:
  /// **'We show them for a few seconds, then you find them again in a grid full of near-identical symbols.'**
  String get challengeIntroHint;

  /// No description provided for @challengeShowSequence.
  ///
  /// In en, this message translates to:
  /// **'Show me the sequence'**
  String get challengeShowSequence;

  /// No description provided for @challengeMemorizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Memorise'**
  String get challengeMemorizeTitle;

  /// No description provided for @challengeMemorizeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'These symbols, in this order. Then they disappear.'**
  String get challengeMemorizeSubtitle;

  /// No description provided for @challengeRecallTitle.
  ///
  /// In en, this message translates to:
  /// **'Rebuild'**
  String get challengeRecallTitle;

  /// No description provided for @challengeRecallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap them in the same order. Watch out for the lookalikes.'**
  String get challengeRecallSubtitle;

  /// No description provided for @challengeBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get challengeBlockedTitle;

  /// No description provided for @challengeExpiredMidway.
  ///
  /// In en, this message translates to:
  /// **'The verification expired before you finished. You can start over.'**
  String get challengeExpiredMidway;

  /// No description provided for @challengeFailedAttempts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{One attempt went wrong. No rush.} other{{count} attempts went wrong. No rush.}}'**
  String challengeFailedAttempts(int count);

  /// No description provided for @challengeGiveUp.
  ///
  /// In en, this message translates to:
  /// **'Never mind'**
  String get challengeGiveUp;

  /// No description provided for @challengeCooldown.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts in a row. Try again in {time}.'**
  String challengeCooldown(String time);

  /// No description provided for @challengeStartFailed.
  ///
  /// In en, this message translates to:
  /// **'The verification could not be started. Try again in a moment.'**
  String get challengeStartFailed;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @onboardingWelcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'A Maori symbol of inner growth.'**
  String get onboardingWelcomeTagline;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Koru is a minimalist launcher and a mindful blocker. It helps you take back your attention — one breath at a time.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingLauncherTitle.
  ///
  /// In en, this message translates to:
  /// **'Use Koru as your launcher'**
  String get onboardingLauncherTitle;

  /// No description provided for @onboardingLauncherBody.
  ///
  /// In en, this message translates to:
  /// **'Set Koru as your default home screen for the full minimalist experience. You can always change this later in Settings.'**
  String get onboardingLauncherBody;

  /// No description provided for @onboardingLauncherCta.
  ///
  /// In en, this message translates to:
  /// **'Set Koru as default launcher'**
  String get onboardingLauncherCta;

  /// No description provided for @onboardingLauncherSkipHint.
  ///
  /// In en, this message translates to:
  /// **'Or skip — Koru works great either way.'**
  String get onboardingLauncherSkipHint;

  /// No description provided for @onboardingPresetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick start'**
  String get onboardingPresetsTitle;

  /// No description provided for @onboardingPresetsBody.
  ///
  /// In en, this message translates to:
  /// **'Tap a preset to create a ready-to-go profile. You can edit it later.'**
  String get onboardingPresetsBody;

  /// No description provided for @onboardingEnterKoru.
  ///
  /// In en, this message translates to:
  /// **'Enter Koru'**
  String get onboardingEnterKoru;

  /// No description provided for @onboardingSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get onboardingSkipForNow;

  /// No description provided for @overlayTakeABreath.
  ///
  /// In en, this message translates to:
  /// **'Take a breath'**
  String get overlayTakeABreath;

  /// No description provided for @overlayFocusModeActive.
  ///
  /// In en, this message translates to:
  /// **'Focus mode is active'**
  String get overlayFocusModeActive;

  /// No description provided for @overlaySectionBlocked.
  ///
  /// In en, this message translates to:
  /// **'Section blocked'**
  String get overlaySectionBlocked;

  /// No description provided for @overlayWebsiteBlocked.
  ///
  /// In en, this message translates to:
  /// **'Website blocked'**
  String get overlayWebsiteBlocked;

  /// No description provided for @overlayPausedBy.
  ///
  /// In en, this message translates to:
  /// **'Paused by “{profile}”'**
  String overlayPausedBy(String profile);

  /// No description provided for @overlayOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Open {app}'**
  String overlayOpenApp(String app);

  /// No description provided for @overlayDontOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Don\'t open {app}'**
  String overlayDontOpenApp(String app);

  /// No description provided for @overlayTapTimerToPause.
  ///
  /// In en, this message translates to:
  /// **'Tap the timer to pause it'**
  String get overlayTapTimerToPause;

  /// No description provided for @overlayPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get overlayPaused;

  /// No description provided for @overlayCountdownSemantics.
  ///
  /// In en, this message translates to:
  /// **'Countdown: {seconds} seconds remaining'**
  String overlayCountdownSemantics(int seconds);

  /// No description provided for @usageLimitActionOpenBeyond.
  ///
  /// In en, this message translates to:
  /// **'open {app} past today\'s limit'**
  String usageLimitActionOpenBeyond(String app);

  /// No description provided for @reelsScrolledToday.
  ///
  /// In en, this message translates to:
  /// **'Scrolled today'**
  String get reelsScrolledToday;

  /// No description provided for @reelsUnit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{reel} other{reels}}'**
  String reelsUnit(int count);

  /// No description provided for @reelsNoneToday.
  ///
  /// In en, this message translates to:
  /// **'None today'**
  String get reelsNoneToday;

  /// No description provided for @reelsNoneTodayWithAverage.
  ///
  /// In en, this message translates to:
  /// **'None today — your average is {average}'**
  String reelsNoneTodayWithAverage(int average);

  /// No description provided for @reelsFirstDays.
  ///
  /// In en, this message translates to:
  /// **'First days of tracking'**
  String get reelsFirstDays;

  /// No description provided for @reelsOnAverage.
  ///
  /// In en, this message translates to:
  /// **'Right on your daily average ({average})'**
  String reelsOnAverage(int average);

  /// No description provided for @reelsMoreThanAverage.
  ///
  /// In en, this message translates to:
  /// **'{delta} more than your daily average ({average})'**
  String reelsMoreThanAverage(int delta, int average);

  /// No description provided for @reelsFewerThanAverage.
  ///
  /// In en, this message translates to:
  /// **'{delta} fewer than your daily average ({average})'**
  String reelsFewerThanAverage(int delta, int average);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
