/// Etichette tradotte per i model di `data/` e le costanti di `core/`.
///
/// Esistono qui e non sui tipi stessi per una ragione sola: sono **testo di
/// UI**, e `data/`/`core/` non importano Flutter — quindi non possono leggere
/// [AppLocalizations]. Tenerle sul model significherebbe o una stringa inglese
/// hardcoded che nessuna lingua può sovrascrivere, o un secondo catalogo di
/// traduzioni accanto agli ARB: entrambe le cose driftano in silenzio.
///
/// Chi aggiunge un'etichetta a un model la aggiunga qui.
library;

import '../../core/constants/day_flags.dart';
import '../../core/constants/profile_types.dart';
import '../../data/models/profile_model.dart';
import '../../domain/entities/achievement.dart';
import '../../domain/entities/blocked_section.dart';
import '../../domain/entities/statistics_period.dart';
import '../../l10n/generated/app_localizations.dart';

extension DayFlagsL10n on AppLocalizations {
  /// Abbreviazione del giorno per un singolo bit di [DayFlags].
  ///
  /// Le abbreviazioni stanno negli ARB e non arrivano da `DateFormat.E()`:
  /// così sono deterministiche nei test e non dipendono
  /// dall'inizializzazione dei dati locale di `intl`.
  String dayShortLabel(int dayBit) => switch (dayBit) {
        DayFlags.monday => dayMon,
        DayFlags.tuesday => dayTue,
        DayFlags.wednesday => dayWed,
        DayFlags.thursday => dayThu,
        DayFlags.friday => dayFri,
        DayFlags.saturday => daySat,
        DayFlags.sunday => daySun,
        _ => '',
      };

  /// Le abbreviazioni dei giorni attivi in [flags], in ordine da lunedì.
  List<String> activeDayLabels(int flags) => DayFlags.ordered
      .where((d) => DayFlags.hasDay(flags, d))
      .map(dayShortLabel)
      .toList(growable: false);

  /// Abbreviazione del giorno per un weekday Dart (1 = lunedì … 7 = domenica),
  /// che è la convenzione di `DateTime.weekday`.
  String weekdayShortLabel(int dartWeekday) =>
      dayShortLabel(DayFlags.fromDartWeekday(dartWeekday));

  /// Abbreviazione del mese (1 = gennaio … 12 = dicembre), la convenzione di
  /// `DateTime.month`.
  String monthShortLabel(int month) => switch (month) {
        1 => monthJan,
        2 => monthFeb,
        3 => monthMar,
        4 => monthApr,
        5 => monthMay,
        6 => monthJun,
        7 => monthJul,
        8 => monthAug,
        9 => monthSep,
        10 => monthOct,
        11 => monthNov,
        12 => monthDec,
        _ => '',
      };
}

extension ProfileModelL10n on ProfileModel {
  /// Titolo da mostrare: quello vero, o un segnaposto se il profilo è stato
  /// salvato senza nome.
  String displayTitleL10n(AppLocalizations l10n) =>
      title.isEmpty ? l10n.profileUntitled : title;

  String modeLabel(AppLocalizations l10n) =>
      blockingMode == BlockingMode.allowlist
          ? l10n.profileModeAllowlist
          : l10n.profileModeBlocklist;

  /// "Ogni giorno" / "Giorni feriali" / "Weekend", oppure l'elenco dei giorni
  /// attivi. Le tre combinazioni con un nome proprio si leggono meglio del
  /// loro elenco esteso, ed è il motivo per cui hanno un ramo dedicato.
  String dayFlagsLabel(AppLocalizations l10n) {
    if (dayFlags == DayFlags.allDays) return l10n.dayEveryDay;
    if (dayFlags == DayFlags.weekdays) return l10n.dayWeekdays;
    if (dayFlags == DayFlags.weekend) return l10n.dayWeekend;
    return l10n.activeDayLabels(dayFlags).join(', ');
  }

  String subtitle(AppLocalizations l10n) {
    final parts = <String>[];
    parts.add(modeLabel(l10n));
    parts.add(l10n.profileAppsCount(apps.length));
    if (websites.isNotEmpty) {
      parts.add(l10n.profileSitesCount(websites.length));
    }
    if (hasTimeCondition && intervals.isNotEmpty) {
      parts.add(intervals
          .map((iv) => iv.fromMinutes == iv.toMinutes
              // from == to e' la fascia 24h (vedi ScheduleUtils.isNowInRange):
              // stamparla come "00:00 - 00:00" leggerebbe come finestra vuota.
              ? l10n.profilesAllDay
              : '${formatMinutesOfDay(iv.fromMinutes)} - '
                  '${formatMinutesOfDay(iv.toMinutes)}')
          .join(', '));
    }
    parts.add(dayFlagsLabel(l10n));
    return parts.join(' · ');
  }
}

extension StatisticsPeriodL10n on StatisticsPeriod {
  String label(AppLocalizations l10n) => switch (this) {
        StatisticsPeriod.today => l10n.statsPeriodToday,
        StatisticsPeriod.week => l10n.statsPeriodWeek,
      };

  /// Come ci si riferisce al periodo PRECEDENTE nel confronto ("+12% rispetto
  /// a ieri"). [shifted] è true quando si sta guardando un giorno passato: lì
  /// il termine di paragone non è "ieri" ma "il giorno prima", e chiamarlo
  /// "ieri" sarebbe una bugia piccola ma ripetuta a ogni apertura.
  String previousRef(AppLocalizations l10n, {required bool shifted}) =>
      switch (this) {
        StatisticsPeriod.today =>
          shifted ? l10n.statsRefDayBefore : l10n.statsRefYesterday,
        StatisticsPeriod.week => l10n.statsRefLastWeek,
      };
}

extension AchievementL10n on Achievement {
  /// Titolo e descrizione risolti per [Achievement.id], come `iconKey` risolve
  /// l'icona. Un id senza traduzione ricade sull'id stesso: preferibile a un
  /// crash e visibile abbastanza da non passare inosservato in review.
  String title(AppLocalizations l10n) => switch (id) {
        'clean_week' => l10n.achievementCleanWeekTitle,
        'intentions_50' => l10n.achievementIntentions50Title,
        'honest_block_100' => l10n.achievementHonestBlock100Title,
        'setup_first_profile' => l10n.achievementFirstProfileTitle,
        'setup_curated' => l10n.achievementCuratedTitle,
        'setup_lockdown' => l10n.achievementLockdownTitle,
        'setup_customized' => l10n.achievementCustomizedTitle,
        _ => id,
      };

  String description(AppLocalizations l10n) => switch (id) {
        'clean_week' => l10n.achievementCleanWeekDesc,
        'intentions_50' => l10n.achievementIntentions50Desc,
        'honest_block_100' => l10n.achievementHonestBlock100Desc,
        'setup_first_profile' => l10n.achievementFirstProfileDesc,
        'setup_curated' => l10n.achievementCuratedDesc,
        'setup_lockdown' => l10n.achievementLockdownDesc,
        'setup_customized' => l10n.achievementCustomizedDesc,
        _ => '',
      };
}

extension AchievementCategoryL10n on AchievementCategory {
  String label(AppLocalizations l10n) => switch (this) {
        AchievementCategory.discipline => l10n.achievementCategoryDiscipline,
        AchievementCategory.setup => l10n.achievementCategorySetup,
      };
}

extension BlockedSectionL10n on BlockedSection {
  /// Il nome dell'app che ospita la sezione. **Non** si traduce: è un marchio.
  String get appLabel => switch (packageName) {
        'com.instagram.android' => 'Instagram',
        'com.google.android.youtube' => 'YouTube',
        _ => packageName,
      };

  /// "Reels", "Storie", "Esplora", "Shorts" — il nome della sezione da solo.
  String shortName(AppLocalizations l10n) => switch (this) {
        BlockedSection.instagramReels => l10n.sectionInstagramReels,
        BlockedSection.instagramStories => l10n.sectionInstagramStories,
        BlockedSection.instagramExplore => l10n.sectionInstagramExplore,
        BlockedSection.youtubeShorts => l10n.sectionYoutubeShorts,
      };

  /// "Instagram Storie" — app + sezione, per le liste che mescolano app
  /// diverse e dove il solo nome della sezione sarebbe ambiguo.
  String fullName(AppLocalizations l10n) => '$appLabel ${shortName(l10n)}';
}

/// `540` → `09:00`. Orario in 24h a prescindere dalla lingua: Koru mostra
/// finestre di blocco, e un `9:00 PM` fra due orari accorciati è più facile da
/// leggere male di un `21:00`.
String formatMinutesOfDay(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}
