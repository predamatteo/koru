import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/presentation/providers/battery_provider.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  // EventChannel uses platform messages — need the binding to mock them.
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = EventChannel('com.koru/battery');

  group('BatteryState', () {
    test('value-object constructor stores level + charging', () {
      const s = BatteryState(level: 50, charging: true);
      expect(s.level, 50);
      expect(s.charging, isTrue);
    });
  });

  group('batteryStateProvider', () {
    tearDown(() {
      binding.defaultBinaryMessenger.setMockStreamHandler(channel, null);
    });

    test('maps a Map payload to BatteryState(level, charging)', () async {
      binding.defaultBinaryMessenger.setMockStreamHandler(
        channel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({'level': 75, 'charging': true});
            events.endOfStream();
          },
        ),
      );

      final h = buildTestContainer();
      addTearDown(h.dispose);

      final state =
          await h.container.read(batteryStateProvider.stream).first;
      expect(state.level, 75);
      expect(state.charging, isTrue);
    });

    test('non-Map payload yields BatteryState(-1, false)', () async {
      binding.defaultBinaryMessenger.setMockStreamHandler(
        channel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success(42);
            events.endOfStream();
          },
        ),
      );

      final h = buildTestContainer();
      addTearDown(h.dispose);

      final state =
          await h.container.read(batteryStateProvider.stream).first;
      expect(state.level, -1);
      expect(state.charging, isFalse);
    });

    test('missing fields default to (-1, false)', () async {
      binding.defaultBinaryMessenger.setMockStreamHandler(
        channel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success(<String, dynamic>{});
            events.endOfStream();
          },
        ),
      );

      final h = buildTestContainer();
      addTearDown(h.dispose);

      final state =
          await h.container.read(batteryStateProvider.stream).first;
      expect(state.level, -1);
      expect(state.charging, isFalse);
    });

    test('charging defaults to false when absent in the payload',
        () async {
      binding.defaultBinaryMessenger.setMockStreamHandler(
        channel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({'level': 33});
            events.endOfStream();
          },
        ),
      );

      final h = buildTestContainer();
      addTearDown(h.dispose);

      final state =
          await h.container.read(batteryStateProvider.stream).first;
      expect(state.level, 33);
      expect(state.charging, isFalse);
    });
  });

  group('backward-compat providers', () {
    tearDown(() {
      binding.defaultBinaryMessenger.setMockStreamHandler(channel, null);
    });

    test('batteryLevelProvider extracts the level from BatteryState',
        () async {
      binding.defaultBinaryMessenger.setMockStreamHandler(
        channel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({'level': 42, 'charging': false});
            events.endOfStream();
          },
        ),
      );

      final h = buildTestContainer();
      addTearDown(h.dispose);

      await h.container.read(batteryStateProvider.stream).first;

      final level = h.container.read(batteryLevelProvider).valueOrNull;
      expect(level, 42);
    });

    test('isChargingProvider extracts the charging flag', () async {
      binding.defaultBinaryMessenger.setMockStreamHandler(
        channel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({'level': 80, 'charging': true});
            events.endOfStream();
          },
        ),
      );

      final h = buildTestContainer();
      addTearDown(h.dispose);

      await h.container.read(batteryStateProvider.stream).first;

      final charging = h.container.read(isChargingProvider).valueOrNull;
      expect(charging, isTrue);
    });
  });
}
