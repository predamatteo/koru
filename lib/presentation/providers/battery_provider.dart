import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';

/// Battery level (0-100). Polled ogni 30s. -1 se non disponibile.
final batteryLevelProvider = StreamProvider<int>((ref) async* {
  final blocking = ref.watch(platformChannelServiceProvider).blocking;
  yield await blocking.getBatteryLevel();
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 30));
    yield await blocking.getBatteryLevel();
  }
});

/// Whether device is currently charging. Polled ogni 10s.
final isChargingProvider = StreamProvider<bool>((ref) async* {
  final blocking = ref.watch(platformChannelServiceProvider).blocking;
  yield await blocking.isCharging();
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 10));
    yield await blocking.isCharging();
  }
});
