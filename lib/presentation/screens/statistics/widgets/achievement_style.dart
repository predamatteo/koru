import 'package:flutter/material.dart';

import '../../../../domain/entities/achievement.dart';

/// Mapper di presentation: converte la chiave stabile [Achievement.iconKey]
/// (domain-puro, nessuna dipendenza da Flutter) nell'`IconData` Material da
/// renderizzare. Tenere allineato con gli `iconKey` di `kAchievementCatalog`.
///
/// Il fallback ([Icons.emoji_events_outlined]) copre chiavi sconosciute così
/// che un nuovo achievement con icona non ancora mappata non causi crash.
const Map<String, IconData> _kIconByKey = <String, IconData>{
  'self_improvement_outlined': Icons.self_improvement_outlined,
  'hourglass_full_outlined': Icons.hourglass_full_outlined,
  'wb_sunny_outlined': Icons.wb_sunny_outlined,
  'emoji_events_outlined': Icons.emoji_events_outlined,
  'auto_awesome_outlined': Icons.auto_awesome_outlined,
  'local_fire_department_outlined': Icons.local_fire_department_outlined,
  'park_outlined': Icons.park_outlined,
  'forest_outlined': Icons.forest_outlined,
  'verified_outlined': Icons.verified_outlined,
  'psychology_outlined': Icons.psychology_outlined,
  'shield_outlined': Icons.shield_outlined,
  'add_circle_outline': Icons.add_circle_outline,
  'tune_outlined': Icons.tune_outlined,
  'lock_outline': Icons.lock_outline,
  'palette_outlined': Icons.palette_outlined,
};

/// `IconData` per [achievement], derivato dalla sua [Achievement.iconKey].
IconData achievementIcon(Achievement achievement) =>
    _kIconByKey[achievement.iconKey] ?? Icons.emoji_events_outlined;
