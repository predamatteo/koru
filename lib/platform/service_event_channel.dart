import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

/// Eventi emessi dal native service al Flutter tramite EventChannel.
sealed class KoruServiceEvent {
  const KoruServiceEvent();

  factory KoruServiceEvent.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'SERVICE_STATE':
        return ServiceStateEvent(running: json['running'] as bool? ?? false);
      case 'BLOCKING_STATE':
        return BlockingStateEvent(
          isBlocking: json['isBlocking'] as bool? ?? false,
          packageName: json['packageName'] as String? ?? '',
          profileId: json['profileId'] as int? ?? -1,
          profileTitle: json['profileTitle'] as String? ?? '',
        );
      case 'QUICK_BLOCK_TICK':
        return QuickBlockTickEvent(
          remainingMs: (json['remainingMs'] as num?)?.toInt() ?? 0,
          totalMs: (json['totalMs'] as num?)?.toInt() ?? 0,
          isPomodoroBreak: json['isPomodoroBreak'] as bool? ?? false,
          isActive: json['isActive'] as bool? ?? false,
          currentCycle: json['currentCycle'] as int? ?? 0,
          totalCycles: json['totalCycles'] as int? ?? 0,
        );
      default:
        return UnknownServiceEvent(raw: json);
    }
  }
}

class ServiceStateEvent extends KoruServiceEvent {
  const ServiceStateEvent({required this.running});
  final bool running;
}

class BlockingStateEvent extends KoruServiceEvent {
  const BlockingStateEvent({
    required this.isBlocking,
    required this.packageName,
    required this.profileId,
    required this.profileTitle,
  });
  final bool isBlocking;
  final String packageName;
  final int profileId;
  final String profileTitle;
}

class QuickBlockTickEvent extends KoruServiceEvent {
  const QuickBlockTickEvent({
    required this.remainingMs,
    required this.totalMs,
    required this.isPomodoroBreak,
    required this.isActive,
    required this.currentCycle,
    required this.totalCycles,
  });
  final int remainingMs;
  final int totalMs;
  final bool isPomodoroBreak;
  final bool isActive;
  final int currentCycle;
  final int totalCycles;
}

class UnknownServiceEvent extends KoruServiceEvent {
  const UnknownServiceEvent({required this.raw});
  final Map<String, dynamic> raw;
}

class ServiceEventChannel {
  ServiceEventChannel();

  static const EventChannel _channel = EventChannel('com.koru/service_events');

  Stream<KoruServiceEvent> events() => _channel.receiveBroadcastStream().map((raw) {
        if (raw is String) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            return KoruServiceEvent.fromJson(decoded);
          }
        }
        return UnknownServiceEvent(raw: {'raw': raw});
      });
}
