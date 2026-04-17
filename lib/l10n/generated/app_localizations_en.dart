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
  String get tabFocus => 'Focus';

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
}
