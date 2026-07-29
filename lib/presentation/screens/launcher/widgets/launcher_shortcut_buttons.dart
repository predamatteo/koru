import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/koru_type.dart';
import '../../../../core/theme/launcher_phase.dart';
import '../../../providers/launcher_shortcuts_provider.dart';

/// Shortcut configurabile agli angoli della barra inferiore del launcher.
/// Tap singolo → launch app. Long press → apre la configurazione per sostituirla.
///
/// **È una parola, non un'icona.** `TEL` e `CAM` in mono spaziato al posto di
/// `Icons.phone_outlined` / `Icons.camera_alt_outlined`: il dogma solo-testo
/// del launcher vale anche per la sua stessa UI, non solo per la lista app.
class LauncherShortcutWord extends ConsumerWidget {
  const LauncherShortcutWord({
    required this.slot,
    required this.label,
    required this.phase,
    required this.semanticLabel,
    super.key,
  });

  final LauncherShortcutSlot slot;

  /// Etichetta breve in maiuscolo (`TEL`, `CAM`).
  final String label;

  final LauncherPhase phase;

  /// Nome esteso per gli screen reader: `TEL` da solo non è pronunciabile.
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
        child: Padding(
          // Asimmetrico: il lato verso il bordo non ha padding, così la parola
          // resta allineata al margine di 24px della composizione.
          padding: EdgeInsets.fromLTRB(
            isLeft ? 0 : 6,
            14,
            isLeft ? 6 : 0,
            14,
          ),
          child: ExcludeSemantics(
            child: Text(
              label,
              style: KoruType.mono(
                size: 12,
                color: phase.ink2,
                trackEm: phase.trackEm,
              ),
            ),
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
