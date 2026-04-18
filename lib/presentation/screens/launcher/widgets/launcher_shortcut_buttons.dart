import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../providers/launcher_shortcuts_provider.dart';

/// Riga con 2 shortcut configurabili (sinistra / destra) per il launcher.
/// Tap singolo → launch app. Long press → apre configurazione per sostituire.
class LauncherShortcutButtons extends ConsumerWidget {
  const LauncherShortcutButtons({super.key});

  Future<void> _launch(WidgetRef ref, String? pkg) async {
    if (pkg == null || pkg.isEmpty) return;
    await ref.read(platformChannelServiceProvider).blocking.launchApp(pkg);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leftPkg =
        ref.watch(effectiveShortcutPackageProvider(LauncherShortcutSlot.left));
    final rightPkg =
        ref.watch(effectiveShortcutPackageProvider(LauncherShortcutSlot.right));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ShortcutButton(
            icon: Icons.phone_outlined,
            semanticLabel: 'Phone',
            onTap: () => _launch(ref, leftPkg),
            onLongPress: () =>
                context.push('${KoruRoutes.launcherShortcuts}?slot=left'),
          ),
          _ShortcutButton(
            icon: Icons.camera_alt_outlined,
            semanticLabel: 'Camera',
            onTap: () => _launch(ref, rightPkg),
            onLongPress: () =>
                context.push('${KoruRoutes.launcherShortcuts}?slot=right'),
          ),
        ],
      ),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    required this.onLongPress,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        customBorder: const CircleBorder(),
        splashColor: KoruColors.textPrimary.withAlpha(30),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(
            icon,
            color: KoruColors.textPrimary.withAlpha(220),
            size: 30,
          ),
        ),
      ),
    );
  }
}
