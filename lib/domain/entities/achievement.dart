import 'package:flutter/material.dart';

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
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.target,
  });

  /// Id stabile (snake_case) — chiave primaria in DB, non tradurre.
  final String id;

  /// Titolo mostrato in UI.
  final String title;

  /// Testo esteso (una frase, tono mindful).
  final String description;

  final IconData icon;
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
    icon: Icons.self_improvement_outlined,
    category: AchievementCategory.focus,
    target: 1,
  ),
  Achievement(
    id: 'focus_hour',
    title: 'Focused hour',
    description: 'Reach 1 hour of total focus time.',
    icon: Icons.hourglass_full_outlined,
    category: AchievementCategory.focus,
    target: 60,
  ),
  Achievement(
    id: 'focus_day',
    title: 'Focused day',
    description: 'Log 4 hours of focus in a single day.',
    icon: Icons.wb_sunny_outlined,
    category: AchievementCategory.focus,
    target: 240,
  ),
  Achievement(
    id: 'focus_dedicated',
    title: 'Dedicated',
    description: '10 hours of lifetime focus time.',
    icon: Icons.emoji_events_outlined,
    category: AchievementCategory.focus,
    target: 600,
  ),
  Achievement(
    id: 'focus_monk',
    title: 'Monk mode',
    description: '50 hours of lifetime focus time.',
    icon: Icons.auto_awesome_outlined,
    category: AchievementCategory.focus,
    target: 3000,
  ),

  // ── Consistency ────────────────────────────────────────────────────────
  Achievement(
    id: 'streak_focus_7',
    title: 'Weekling',
    description: 'Seven-day focus streak.',
    icon: Icons.local_fire_department_outlined,
    category: AchievementCategory.consistency,
    target: 7,
  ),
  Achievement(
    id: 'streak_focus_30',
    title: 'Rooted',
    description: 'Thirty-day focus streak.',
    icon: Icons.park_outlined,
    category: AchievementCategory.consistency,
    target: 30,
  ),
  Achievement(
    id: 'streak_focus_100',
    title: 'Centennial',
    description: 'One hundred days of focus in a row.',
    icon: Icons.forest_outlined,
    category: AchievementCategory.consistency,
    target: 100,
  ),

  // ── Discipline ─────────────────────────────────────────────────────────
  Achievement(
    id: 'clean_week',
    title: 'Clean week',
    description: 'Seven days without exceeding any daily limit.',
    icon: Icons.verified_outlined,
    category: AchievementCategory.discipline,
    target: 7,
  ),
  Achievement(
    id: 'intentions_50',
    title: 'Mindful chooser',
    description: 'Log an intention 50 times on the block overlay.',
    icon: Icons.psychology_outlined,
    category: AchievementCategory.discipline,
    target: 50,
  ),
  Achievement(
    id: 'honest_block_100',
    title: 'Honest block',
    description: 'Respect a block (no bypass) 100 times.',
    icon: Icons.shield_outlined,
    category: AchievementCategory.discipline,
    target: 100,
  ),

  // ── Setup ──────────────────────────────────────────────────────────────
  Achievement(
    id: 'setup_first_profile',
    title: 'First profile',
    description: 'Create your first blocking profile.',
    icon: Icons.add_circle_outline,
    category: AchievementCategory.setup,
    target: 1,
  ),
  Achievement(
    id: 'setup_curated',
    title: 'Curated',
    description: 'Set daily limits on 3 or more apps.',
    icon: Icons.tune_outlined,
    category: AchievementCategory.setup,
    target: 3,
  ),
  Achievement(
    id: 'setup_lockdown',
    title: 'Lockdown',
    description: 'Enable strict mode at least once.',
    icon: Icons.lock_outline,
    category: AchievementCategory.setup,
    target: 1,
  ),
  Achievement(
    id: 'setup_customized',
    title: 'Customized',
    description: 'Personalize the overlay for at least one app.',
    icon: Icons.palette_outlined,
    category: AchievementCategory.setup,
    target: 1,
  ),
];

Achievement? achievementById(String id) =>
    kAchievementCatalog.where((a) => a.id == id).firstOrNull;
