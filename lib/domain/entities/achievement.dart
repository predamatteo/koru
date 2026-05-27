/// Categoria di un [Achievement] — usata per raggruppamento in UI
/// e colorazione del badge.
enum AchievementCategory {
  focus,
  consistency,
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
    required this.title,
    required this.description,
    required this.iconKey,
    required this.category,
    required this.target,
  });

  /// Id stabile (snake_case) — chiave primaria in DB, non tradurre.
  final String id;

  /// Titolo mostrato in UI.
  final String title;

  /// Testo esteso (una frase, tono mindful).
  final String description;

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

/// Il catalogo MVP — 15 achievement. IDs stabili, non rinominare.
const kAchievementCatalog = <Achievement>[
  // ── Focus ──────────────────────────────────────────────────────────────
  Achievement(
    id: 'focus_first',
    title: 'First focus',
    description: 'Complete your first focus session.',
    iconKey: 'self_improvement_outlined',
    category: AchievementCategory.focus,
    target: 1,
  ),
  Achievement(
    id: 'focus_hour',
    title: 'Focused hour',
    description: 'Reach 1 hour of total focus time.',
    iconKey: 'hourglass_full_outlined',
    category: AchievementCategory.focus,
    target: 60,
  ),
  Achievement(
    id: 'focus_day',
    title: 'Focused day',
    description: 'Log 4 hours of focus in a single day.',
    iconKey: 'wb_sunny_outlined',
    category: AchievementCategory.focus,
    target: 240,
  ),
  Achievement(
    id: 'focus_dedicated',
    title: 'Dedicated',
    description: '10 hours of lifetime focus time.',
    iconKey: 'emoji_events_outlined',
    category: AchievementCategory.focus,
    target: 600,
  ),
  Achievement(
    id: 'focus_monk',
    title: 'Monk mode',
    description: '50 hours of lifetime focus time.',
    iconKey: 'auto_awesome_outlined',
    category: AchievementCategory.focus,
    target: 3000,
  ),

  // ── Consistency ────────────────────────────────────────────────────────
  Achievement(
    id: 'streak_focus_7',
    title: 'Weekling',
    description: 'Seven-day focus streak.',
    iconKey: 'local_fire_department_outlined',
    category: AchievementCategory.consistency,
    target: 7,
  ),
  Achievement(
    id: 'streak_focus_30',
    title: 'Rooted',
    description: 'Thirty-day focus streak.',
    iconKey: 'park_outlined',
    category: AchievementCategory.consistency,
    target: 30,
  ),
  Achievement(
    id: 'streak_focus_100',
    title: 'Centennial',
    description: 'One hundred days of focus in a row.',
    iconKey: 'forest_outlined',
    category: AchievementCategory.consistency,
    target: 100,
  ),

  // ── Discipline ─────────────────────────────────────────────────────────
  Achievement(
    id: 'clean_week',
    title: 'Clean week',
    description: 'Seven days without exceeding any daily limit.',
    iconKey: 'verified_outlined',
    category: AchievementCategory.discipline,
    target: 7,
  ),
  Achievement(
    id: 'intentions_50',
    title: 'Mindful chooser',
    description: 'Log an intention 50 times on the block overlay.',
    iconKey: 'psychology_outlined',
    category: AchievementCategory.discipline,
    target: 50,
  ),
  Achievement(
    id: 'honest_block_100',
    title: 'Honest block',
    description: 'Respect a block (no bypass) 100 times.',
    iconKey: 'shield_outlined',
    category: AchievementCategory.discipline,
    target: 100,
  ),

  // ── Setup ──────────────────────────────────────────────────────────────
  Achievement(
    id: 'setup_first_profile',
    title: 'First profile',
    description: 'Create your first blocking profile.',
    iconKey: 'add_circle_outline',
    category: AchievementCategory.setup,
    target: 1,
  ),
  Achievement(
    id: 'setup_curated',
    title: 'Curated',
    description: 'Set daily limits on 3 or more apps.',
    iconKey: 'tune_outlined',
    category: AchievementCategory.setup,
    target: 3,
  ),
  Achievement(
    id: 'setup_lockdown',
    title: 'Lockdown',
    description: 'Enable strict mode at least once.',
    iconKey: 'lock_outline',
    category: AchievementCategory.setup,
    target: 1,
  ),
  Achievement(
    id: 'setup_customized',
    title: 'Customized',
    description: 'Personalize the overlay for at least one app.',
    iconKey: 'palette_outlined',
    category: AchievementCategory.setup,
    target: 1,
  ),
];

Achievement? achievementById(String id) =>
    kAchievementCatalog.where((a) => a.id == id).firstOrNull;
