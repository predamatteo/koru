import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../providers/launcher_shortcuts_provider.dart';

/// Shortcut configurabile a un angolo della barra inferiore del launcher.
/// Tap singolo → launch app. Long press → apre la configurazione per
/// sostituirla.
///
/// È un icon button Material 3: forma circolare, bersaglio da 48dp, ripple
/// contenuto nel cerchio. Serve un [InkWell] e non un [IconButton] perché
/// quest'ultimo non espone `onLongPress`, che qui è l'unico modo per
/// riassegnare lo slot.
class LauncherShortcutButton extends ConsumerWidget {
  const LauncherShortcutButton({
    required this.slot,
    required this.icon,
    required this.semanticLabel,
    super.key,
  });

  final LauncherShortcutSlot slot;
  final IconData icon;
  final String semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pkg = ref.watch(effectiveShortcutPackageProvider(slot));
    final isLeft = slot == LauncherShortcutSlot.left;

    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: () => _launch(ref, pkg),
        onLongPress: () => context.push(
          '${KoruRoutes.launcherShortcuts}?slot=${isLeft ? 'left' : 'right'}',
        ),
        customBorder: const CircleBorder(),
        splashColor: KoruColors.textPrimary.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(
            icon,
            size: 28,
            color: KoruColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _launch(WidgetRef ref, String? pkg) async {
    if (pkg == null || pkg.isEmpty) return;
    await ref.read(platformChannelServiceProvider).blocking.launchApp(pkg);
  }
}
