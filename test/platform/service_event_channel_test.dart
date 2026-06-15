import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/platform/service_event_channel.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const eventChannel = EventChannel('com.koru/service_events');

  group('KoruServiceEvent.fromJson', () {
    test('SERVICE_STATE → ServiceStateEvent(running)', () {
      final event = KoruServiceEvent.fromJson({
        'type': 'SERVICE_STATE',
        'running': true,
      });
      expect(event, isA<ServiceStateEvent>());
      expect((event as ServiceStateEvent).running, isTrue);
    });

    test('SERVICE_STATE missing running → false', () {
      final event = KoruServiceEvent.fromJson({'type': 'SERVICE_STATE'});
      expect(event, isA<ServiceStateEvent>());
      expect((event as ServiceStateEvent).running, isFalse);
    });

    test('BLOCKING_STATE parses all fields', () {
      final event = KoruServiceEvent.fromJson({
        'type': 'BLOCKING_STATE',
        'isBlocking': true,
        'packageName': 'com.instagram.android',
        'profileId': 5,
        'profileTitle': 'Focus',
      });
      expect(event, isA<BlockingStateEvent>());
      final b = event as BlockingStateEvent;
      expect(b.isBlocking, isTrue);
      expect(b.packageName, 'com.instagram.android');
      expect(b.profileId, 5);
      expect(b.profileTitle, 'Focus');
    });

    test('BLOCKING_STATE with missing fields uses defaults', () {
      final event = KoruServiceEvent.fromJson({'type': 'BLOCKING_STATE'});
      expect(event, isA<BlockingStateEvent>());
      final b = event as BlockingStateEvent;
      expect(b.isBlocking, isFalse);
      expect(b.packageName, '');
      expect(b.profileId, -1);
      expect(b.profileTitle, '');
    });

    test('QUICK_BLOCK_TICK parses all fields', () {
      final event = KoruServiceEvent.fromJson({
        'type': 'QUICK_BLOCK_TICK',
        'remainingMs': 30000,
        'totalMs': 60000,
        'isPomodoroBreak': true,
        'isActive': true,
        'currentCycle': 2,
        'totalCycles': 4,
      });
      expect(event, isA<QuickBlockTickEvent>());
      final t = event as QuickBlockTickEvent;
      expect(t.remainingMs, 30000);
      expect(t.totalMs, 60000);
      expect(t.isPomodoroBreak, isTrue);
      expect(t.isActive, isTrue);
      expect(t.currentCycle, 2);
      expect(t.totalCycles, 4);
    });

    test('QUICK_BLOCK_TICK coerces num to int', () {
      final event = KoruServiceEvent.fromJson({
        'type': 'QUICK_BLOCK_TICK',
        'remainingMs': 30000.5,
        'totalMs': 60000.7,
      });
      final t = event as QuickBlockTickEvent;
      expect(t.remainingMs, 30000);
      expect(t.totalMs, 60000);
    });

    test('QUICK_BLOCK_TICK uses defaults when fields absent', () {
      final event = KoruServiceEvent.fromJson({'type': 'QUICK_BLOCK_TICK'});
      final t = event as QuickBlockTickEvent;
      expect(t.remainingMs, 0);
      expect(t.totalMs, 0);
      expect(t.isPomodoroBreak, isFalse);
      expect(t.isActive, isFalse);
      expect(t.currentCycle, 0);
      expect(t.totalCycles, 0);
    });

    test('QUICK_BLOCK_FINISHED → QuickBlockFinishedEvent', () {
      final event = KoruServiceEvent.fromJson({'type': 'QUICK_BLOCK_FINISHED'});
      expect(event, isA<QuickBlockFinishedEvent>());
    });

    test('PACKAGE_CHANGED parses kind + packageName', () {
      final event = KoruServiceEvent.fromJson({
        'type': 'PACKAGE_CHANGED',
        'kind': 'added',
        'packageName': 'com.example',
      });
      expect(event, isA<PackageChangedEvent>());
      final p = event as PackageChangedEvent;
      expect(p.kind, 'added');
      expect(p.packageName, 'com.example');
    });

    test('PACKAGE_CHANGED with replaced kind', () {
      final event = KoruServiceEvent.fromJson({
        'type': 'PACKAGE_CHANGED',
        'kind': 'replaced',
        'packageName': 'com.x',
      });
      final p = event as PackageChangedEvent;
      expect(p.kind, 'replaced');
    });

    test('PACKAGE_CHANGED with missing fields defaults to empty strings', () {
      final event = KoruServiceEvent.fromJson({'type': 'PACKAGE_CHANGED'});
      final p = event as PackageChangedEvent;
      expect(p.kind, '');
      expect(p.packageName, '');
    });

    test('OPEN_APPS_COUNT parses count+seq, defaults to 0', () {
      final event = KoruServiceEvent.fromJson({
        'type': 'OPEN_APPS_COUNT',
        'count': 4,
        'seq': 9,
      });
      expect((event as OpenAppsCountEvent).count, 4);
      expect(event.seq, 9);

      final empty = KoruServiceEvent.fromJson({'type': 'OPEN_APPS_COUNT'});
      expect((empty as OpenAppsCountEvent).count, 0);
      expect(empty.seq, 0);
    });

    test('Unknown type → UnknownServiceEvent containing raw map', () {
      final raw = <String, dynamic>{'type': 'NOPE', 'extra': 1};
      final event = KoruServiceEvent.fromJson(raw);
      expect(event, isA<UnknownServiceEvent>());
      expect((event as UnknownServiceEvent).raw, raw);
    });

    test('Missing type → UnknownServiceEvent', () {
      final raw = <String, dynamic>{'foo': 'bar'};
      final event = KoruServiceEvent.fromJson(raw);
      expect(event, isA<UnknownServiceEvent>());
      expect((event as UnknownServiceEvent).raw, raw);
    });
  });

  group('ServiceEventChannel.events() — stream integration', () {
    tearDown(() {
      binding.defaultBinaryMessenger
          .setMockStreamHandler(eventChannel, null);
    });

    test('decodes JSON-string payloads into typed events', () async {
      binding.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success(jsonEncode({
              'type': 'SERVICE_STATE',
              'running': true,
            }));
            events.endOfStream();
          },
        ),
      );

      final events = await ServiceEventChannel().events().toList();
      expect(events, hasLength(1));
      expect(events.first, isA<ServiceStateEvent>());
      expect((events.first as ServiceStateEvent).running, isTrue);
    });

    test('decodes BLOCKING_STATE event over the stream', () async {
      binding.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success(jsonEncode({
              'type': 'BLOCKING_STATE',
              'isBlocking': true,
              'packageName': 'com.instagram.android',
              'profileId': 1,
              'profileTitle': 'Focus',
            }));
            events.endOfStream();
          },
        ),
      );

      final events = await ServiceEventChannel().events().toList();
      expect(events, hasLength(1));
      final blocking = events.first as BlockingStateEvent;
      expect(blocking.isBlocking, isTrue);
      expect(blocking.packageName, 'com.instagram.android');
      expect(blocking.profileId, 1);
      expect(blocking.profileTitle, 'Focus');
    });

    test('non-string raw payload → UnknownServiceEvent wrapping the raw value',
        () async {
      binding.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success(42);
            events.endOfStream();
          },
        ),
      );

      final events = await ServiceEventChannel().events().toList();
      expect(events, hasLength(1));
      expect(events.first, isA<UnknownServiceEvent>());
      expect((events.first as UnknownServiceEvent).raw, {'raw': 42});
    });

    test('string payload that is NOT a JSON object → UnknownServiceEvent',
        () async {
      final notObject = jsonEncode(<int>[1, 2, 3]);
      binding.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success(notObject);
            events.endOfStream();
          },
        ),
      );

      final events = await ServiceEventChannel().events().toList();
      expect(events, hasLength(1));
      expect(events.first, isA<UnknownServiceEvent>());
    });

    test('multiple events arrive in order', () async {
      binding.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success(jsonEncode({
              'type': 'SERVICE_STATE',
              'running': true,
            }));
            events.success(jsonEncode({
              'type': 'PACKAGE_CHANGED',
              'kind': 'added',
              'packageName': 'com.x',
            }));
            events.endOfStream();
          },
        ),
      );

      final events = await ServiceEventChannel().events().toList();
      expect(events, hasLength(2));
      expect(events[0], isA<ServiceStateEvent>());
      expect(events[1], isA<PackageChangedEvent>());
      expect((events[1] as PackageChangedEvent).kind, 'added');
      expect((events[1] as PackageChangedEvent).packageName, 'com.x');
    });
  });
}
