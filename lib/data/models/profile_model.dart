import '../../core/constants/day_flags.dart';
import '../../core/constants/profile_types.dart';
import '../database/app_database.dart';

/// Aggregato Profile + relazioni (app, websites, intervals, usage limits).
class ProfileModel {
  const ProfileModel({
    required this.data,
    this.apps = const [],
    this.websites = const [],
    this.intervals = const [],
    this.usageLimits = const [],
  });

  final Profile data;
  final List<AppProfileRelation> apps;
  final List<WebsiteRule> websites;
  final List<Interval> intervals;
  final List<UsageLimit> usageLimits;

  // ─── Convenience getters ───────────────────────────────────────────────────
  int get id => data.id;
  String get title => data.title;

  String get emoji => data.emoji;
  String get colorHex => data.colorHex;
  bool get isEnabled => data.isEnabled;
  int get blockingMode => data.blockingMode;
  int get dayFlags => data.dayFlags;
  int get typeCombinations => data.typeCombinations;
  bool get isPaused => data.pausedUntil != 0;

  bool get hasTimeCondition =>
      ProfileType.hasType(typeCombinations, ProfileType.time);
  bool get hasUsageLimit =>
      ProfileType.hasType(typeCombinations, ProfileType.usageLimit);

  // `displayTitle`, `modeLabel`, `dayFlagsLabel` e `subtitle` NON stanno qui:
  // sono testo tradotto e questo file non importa Flutter, quindi non pu\u00f2
  // leggere `AppLocalizations`. Vivono come estensione in
  // `presentation/l10n/model_labels.dart`.
}
