import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/koru_colors.dart';
import '../../core/router/app_router.dart';
import '../providers/achievements_provider.dart';

/// Listener discreto (silenzioso in idle) che mostra uno snackbar quando
/// arriva un nuovo unlock dal [newAchievementUnlocksStreamProvider].
/// Montato a livello di root dentro `app.dart`.
class AchievementUnlockListener extends ConsumerWidget {
  const AchievementUnlockListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(newAchievementUnlocksStreamProvider, (prev, next) {
      final a = next.valueOrNull;
      if (a == null) return;
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          duration: const Duration(seconds: 4),
          backgroundColor: KoruColors.surface,
          content: Row(
            children: [
              Icon(a.icon, color: KoruColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Achievement unlocked',
                      style: TextStyle(
                        color: KoruColors.textSecondary,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.title,
                      style: const TextStyle(
                        color: KoruColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
    return child;
  }
}
