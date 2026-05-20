import 'dart:convert';

import 'package:flutter/material.dart';

/// Configurazione dell'overlay di blocco, serializzabile in JSON per
/// persistenza in Drift (`app_profile_relations.overlay_config_json`)
/// e per trasmissione al native tramite MethodChannel.
class OverlayConfig {
  const OverlayConfig({
    this.backgroundColorHex = '#5C8262',
    this.messageTitle,
    this.messageSubtitle,
    this.countdownSeconds = 8,
    this.shakeEnabled = false,
    this.allowBypassAfterCountdown = true,
  });

  final String backgroundColorHex;
  final String? messageTitle;
  final String? messageSubtitle;
  final int countdownSeconds;
  final bool shakeEnabled;
  final bool allowBypassAfterCountdown;

  /// Default Koru — palette primary (#5C8262), nessun messaggio custom,
  /// countdown 8s, bypass consentito a fine countdown.
  static const OverlayConfig defaults = OverlayConfig();

  Color get backgroundColor {
    final hex = backgroundColorHex.replaceFirst('#', '');
    final value = int.parse(hex, radix: 16);
    return Color(0xFF000000 | value);
  }

  Map<String, dynamic> toJson() => {
    'backgroundColorHex': backgroundColorHex,
    'messageTitle': messageTitle,
    'messageSubtitle': messageSubtitle,
    'countdownSeconds': countdownSeconds,
    'shakeEnabled': shakeEnabled,
    'allowBypassAfterCountdown': allowBypassAfterCountdown,
  };

  String toJsonString() => jsonEncode(toJson());

  factory OverlayConfig.fromJson(Map<String, dynamic> json) => OverlayConfig(
    backgroundColorHex: json['backgroundColorHex'] as String? ?? '#5C8262',
    messageTitle: json['messageTitle'] as String?,
    messageSubtitle: json['messageSubtitle'] as String?,
    countdownSeconds: (json['countdownSeconds'] as num?)?.toInt() ?? 8,
    shakeEnabled: json['shakeEnabled'] as bool? ?? false,
    allowBypassAfterCountdown:
        json['allowBypassAfterCountdown'] as bool? ?? true,
  );

  factory OverlayConfig.fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return OverlayConfig.fromJson(decoded);
      }
    } catch (_) {}
    return defaults;
  }

  OverlayConfig copyWith({
    String? backgroundColorHex,
    String? messageTitle,
    String? messageSubtitle,
    int? countdownSeconds,
    bool? shakeEnabled,
    bool? allowBypassAfterCountdown,
  }) => OverlayConfig(
    backgroundColorHex: backgroundColorHex ?? this.backgroundColorHex,
    messageTitle: messageTitle ?? this.messageTitle,
    messageSubtitle: messageSubtitle ?? this.messageSubtitle,
    countdownSeconds: countdownSeconds ?? this.countdownSeconds,
    shakeEnabled: shakeEnabled ?? this.shakeEnabled,
    allowBypassAfterCountdown:
        allowBypassAfterCountdown ?? this.allowBypassAfterCountdown,
  );
}
