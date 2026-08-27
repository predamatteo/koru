/// Categoria di un [Achievement] — usata per raggruppamento in UI
/// e colorazione del badge.
enum AchievementCategory {
  discipline,
  setup,
}

/// Definizione statica di un achievement. Il catalogo è immutabile e
/// hard-coded in [kAchievementCatalog]; lo stato "sbloccato" è persistito
/// in `achievements_unlocked` (solo id + timestamp).
///
/// Il layer domain resta puro (nessuna dipendenza da Flutter): l'icona è
/// rappresentata da una chiave stabile [iconKey] (snake_case) che la
/// presentation mappa a un `IconData` tramite `achievementIcon` in
/// `presentation/screens/statistics/widgets/achievement_style.dart`.
class Achievement {
  const Achievement({
    required this.id,
    required this.iconKey,
    required this.category,
    required this.target,
  });

  /// Id stabile (snake_case) — chiave primaria in DB, non tradurre.
  ///
  /// È anche la chiave con cui la presentation recupera titolo e descrizione
  /// tradotti: `achievementTitle` / `achievementDescription` in
  /// `presentation/l10n/model_labels.dart`. Stanno lì e non qui per lo stesso
  /// motivo di [iconKey] — questo layer è puro e non vede Flutter.
  final String id;

  /// Chiave stabile dell'icona (snake_case). La presentation la converte in
  /// `IconData` — vedi `achievementIcon` nel mapper di presentation. Tenere
  /// allineata con la mappa lì definita.
  final String iconKey;

  final AchievementCategory category;

  /// Soglia numerica target (minuti, count, ecc). Serve per la progress
  /// bar "X / target" nella schermata dedicata. Per achievement binari
  /// (es. "strict mode toggled") è `1`.
  final int target;
}

/// Il catalogo MVP — 7 achievement. IDs stabili, non rinominare.
///
/// Gli 8 achievement `focus_*` / `streak_focus_*` sono stati RIMOSSI insieme
/// alla tab Focus (quick block + pomodoro): erano gli unici alimentati dalle
/// sessioni a tempo, quindi senza quella superficie sarebbero rimasti a zero
/// per sempre. Le righe già sbloccate restano in `achievements_unlocked` ma
/// non hanno più un [Achievement] corrispondente — [achievementById] ritorna
/// `null` e la UI le ignora. Non riusare quegli id per achievement nuovi.
const kAchievementCatalog = <Achievement>[
  // ── Discipline ─────────────────────────────────────────────────────────
  Achievement(
    id: 'clean_week',
    iconKey: 'verified_outlined',
    category: AchievementCategory.discipline,
    target: 7,
  ),
  Achievement(
    id: 'intentions_50',
    iconKey: 'psychology_outlined',
    category: AchievementCategory.discipline,
    target: 50,
  ),
  Achievement(
    id: 'honest_block_100',
    iconKey: 'shield_outlined',
    category: AchievementCategory.discipline,
    target: 100,
  ),

  // ── Setup ──────────────────────────────────────────────────────────────
  Achievement(
    id: 'setup_first_profile',
    iconKey: 'add_circle_outline',
    category: AchievementCategory.setup,
    target: 1,
  ),
  Achievement(
    id: 'setup_curated',
    iconKey: 'tune_outlined',
    category: AchievementCategory.setup,
    target: 3,
  ),
  Achievement(
    id: 'setup_lockdown',
    iconKey: 'lock_outline',
    category: AchievementCategory.setup,
    target: 1,
  ),
  Achievement(
    id: 'setup_customized',
    iconKey: 'palette_outlined',
    category: AchievementCategory.setup,
    target: 1,
  ),
];

Achievement? achievementById(String id) =>
    kAchievementCatalog.where((a) => a.id == id).firstOrNull;
