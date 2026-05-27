import '../entities/achievement.dart';

/// Porta narrow di cui il valutatore ha bisogno per leggere/scrivere lo
/// stato di unlock. Tiene il layer domain disaccoppiato dalla concreta
/// `AchievementsRepository` di `data/` (inversione di dipendenza, ARCH-07):
/// è `data/` a implementare questa interfaccia, non il contrario.
abstract class AchievementsGateway {
  /// Insieme degli id già sbloccati.
  Future<Set<String>> getUnlockedIds();

  /// Sblocca [id] (idempotente). Ritorna true se era un nuovo unlock.
  Future<bool> unlock(String id);
}

/// Input per il valutatore: aggregati correnti che vengono confrontati
/// con i target del catalogo.
class AchievementStats {
  const AchievementStats({
    required this.totalFocusMinutes,
    required this.focusMinutesToday,
    required this.focusStreakCurrent,
    required this.cleanStreakCurrent,
    required this.intentionsCount,
    required this.honestBlocksCount,
    required this.profilesCount,
    required this.appsWithLimitsCount,
    required this.strictModeEnabled,
    required this.appsWithCustomOverlayCount,
  });

  final int totalFocusMinutes;
  final int focusMinutesToday;
  final int focusStreakCurrent;
  final int cleanStreakCurrent;
  final int intentionsCount;
  final int honestBlocksCount;
  final int profilesCount;
  final int appsWithLimitsCount;
  final bool strictModeEnabled;
  final int appsWithCustomOverlayCount;
}

/// Mappa id → criterio "soddisfatto?" valutato contro [AchievementStats].
/// Tenere allineato con [kAchievementCatalog].
bool _isSatisfied(Achievement a, AchievementStats s) {
  switch (a.id) {
    case 'focus_first':
      return s.totalFocusMinutes >= 1;
    case 'focus_hour':
      return s.totalFocusMinutes >= 60;
    case 'focus_day':
      return s.focusMinutesToday >= 240;
    case 'focus_dedicated':
      return s.totalFocusMinutes >= 600;
    case 'focus_monk':
      return s.totalFocusMinutes >= 3000;
    case 'streak_focus_7':
      return s.focusStreakCurrent >= 7;
    case 'streak_focus_30':
      return s.focusStreakCurrent >= 30;
    case 'streak_focus_100':
      return s.focusStreakCurrent >= 100;
    case 'clean_week':
      return s.cleanStreakCurrent >= 7;
    case 'intentions_50':
      return s.intentionsCount >= 50;
    case 'honest_block_100':
      return s.honestBlocksCount >= 100;
    case 'setup_first_profile':
      return s.profilesCount >= 1;
    case 'setup_curated':
      return s.appsWithLimitsCount >= 3;
    case 'setup_lockdown':
      return s.strictModeEnabled;
    case 'setup_customized':
      return s.appsWithCustomOverlayCount >= 1;
    default:
      return false;
  }
}

/// Valuta il catalogo contro [stats] e sblocca tutti gli achievement
/// soddisfatti non ancora sbloccati. Ritorna la lista dei nuovi unlock
/// (per mostrare toast in UI).
Future<List<Achievement>> evaluateAchievements({
  required AchievementStats stats,
  required AchievementsGateway repo,
}) async {
  final unlocked = await repo.getUnlockedIds();
  final newly = <Achievement>[];
  for (final a in kAchievementCatalog) {
    if (unlocked.contains(a.id)) continue;
    if (_isSatisfied(a, stats)) {
      final unlockedNow = await repo.unlock(a.id);
      if (unlockedNow) newly.add(a);
    }
  }
  return newly;
}

/// Ritorna il valore di progresso corrente (0..target) per [a] dato
/// [stats]. Usato dalla UI "All achievements" per le progress bar.
int achievementProgress(Achievement a, AchievementStats s) {
  switch (a.id) {
    case 'focus_first':
      return s.totalFocusMinutes >= 1 ? 1 : 0;
    case 'focus_hour':
      return s.totalFocusMinutes.clamp(0, 60);
    case 'focus_day':
      return s.focusMinutesToday.clamp(0, 240);
    case 'focus_dedicated':
      return s.totalFocusMinutes.clamp(0, 600);
    case 'focus_monk':
      return s.totalFocusMinutes.clamp(0, 3000);
    case 'streak_focus_7':
      return s.focusStreakCurrent.clamp(0, 7);
    case 'streak_focus_30':
      return s.focusStreakCurrent.clamp(0, 30);
    case 'streak_focus_100':
      return s.focusStreakCurrent.clamp(0, 100);
    case 'clean_week':
      return s.cleanStreakCurrent.clamp(0, 7);
    case 'intentions_50':
      return s.intentionsCount.clamp(0, 50);
    case 'honest_block_100':
      return s.honestBlocksCount.clamp(0, 100);
    case 'setup_first_profile':
      return s.profilesCount >= 1 ? 1 : 0;
    case 'setup_curated':
      return s.appsWithLimitsCount.clamp(0, 3);
    case 'setup_lockdown':
      return s.strictModeEnabled ? 1 : 0;
    case 'setup_customized':
      return s.appsWithCustomOverlayCount.clamp(0, 1);
    default:
      return 0;
  }
}
