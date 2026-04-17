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
  bool get isQuickBlock =>
      ProfileType.hasType(typeCombinations, ProfileType.quickBlock);

  String get modeLabel =>
      blockingMode == BlockingMode.allowlist ? 'Allowlist' : 'Blocklist';

  String get dayFlagsLabel {
    if (dayFlags == DayFlags.allDays) return 'Every day';
    if (dayFlags == DayFlags.weekdays) return 'Weekdays';
    if (dayFlags == DayFlags.weekend) return 'Weekend';
    return DayFlags.activeLabels(dayFlags).join(', ');
  }

  String get subtitle {
    final parts = <String>[];
    parts.add(modeLabel);
    parts.add('${apps.length} apps');
    if (websites.isNotEmpty) parts.add('${websites.length} sites');
    if (hasTimeCondition && intervals.isNotEmpty) {
      final interval = intervals.first;
      parts.add('${_formatMinutes(interval.fromMinutes)} - ${_formatMinutes(interval.toMinutes)}');
    }
    parts.add(dayFlagsLabel);
    return parts.join(' \u00b7 ');
  }

  static String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
