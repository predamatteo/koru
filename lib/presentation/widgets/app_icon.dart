import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_list_provider.dart';

/// Icona di un'app caricata on-demand via [appIconProvider] (decode nativo su
/// thread di background, vedi `BlockingChannel.getAppIcon`).
///
/// Sostituisce il vecchio `Image.memory(app.iconBytes!)`: `getInstalledApps`
/// non trasporta più le icone (le decodava tutte al cold start). Mostra un
/// placeholder della stessa dimensione finché i byte non arrivano o se l'app
/// non ha icona, così il layout non salta.
class AppIcon extends ConsumerWidget {
  const AppIcon({required this.packageName, this.size = 40, super.key});

  final String packageName;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(appIconProvider(packageName)).valueOrNull;
    if (bytes == null) return SizedBox(width: size, height: size);
    return Image.memory(
      bytes,
      width: size,
      height: size,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
    );
  }
}
