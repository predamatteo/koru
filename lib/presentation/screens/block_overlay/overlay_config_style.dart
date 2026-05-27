import 'package:flutter/material.dart';

import '../../../domain/entities/overlay_config.dart';

/// Estensione di presentation: deriva il `Color` di sfondo dalla stringa hex
/// domain-pura [OverlayConfig.backgroundColorHex]. Tenere il layer domain
/// libero da dipendenze Flutter — la conversione vive qui.
extension OverlayConfigStyle on OverlayConfig {
  /// Colore di sfondo dell'overlay, con alpha pieno (`0xFF`). Parsing
  /// identico al precedente getter presente nell'entità.
  Color get backgroundColor {
    final hex = backgroundColorHex.replaceFirst('#', '');
    final value = int.parse(hex, radix: 16);
    return Color(0xFF000000 | value);
  }
}
