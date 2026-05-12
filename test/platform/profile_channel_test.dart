import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/platform/profile_channel.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channelName = 'com.koru/profiles';
  late List<MethodCall> calls;

  void setMockHandler(Future<Object?> Function(MethodCall) handler) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(channelName),
      (call) async {
        calls.add(call);
        return handler(call);
      },
    );
  }

  void clearMockHandler() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(channelName),
      null,
    );
  }

  setUp(() {
    calls = [];
  });

  tearDown(() {
    clearMockHandler();
  });

  group('ProfileChannel', () {
    test('notifyProfileChanged sends profileId argument', () async {
      setMockHandler((_) async => null);
      await ProfileChannel().notifyProfileChanged(42);
      expect(calls, hasLength(1));
      expect(calls.first.method, 'notifyProfileChanged');
      expect(calls.first.arguments, {'profileId': 42});
    });

    test('notifyProfileToggled(enabled=true) sends profileId + enabled',
        () async {
      setMockHandler((_) async => null);
      await ProfileChannel()
          .notifyProfileToggled(profileId: 7, enabled: true);
      expect(calls.first.method, 'notifyProfileToggled');
      expect(calls.first.arguments, {'profileId': 7, 'enabled': true});
    });

    test('notifyProfileToggled(enabled=false)', () async {
      setMockHandler((_) async => null);
      await ProfileChannel()
          .notifyProfileToggled(profileId: 7, enabled: false);
      expect(calls.first.arguments, {'profileId': 7, 'enabled': false});
    });

    test('setProfilePaused without pausedUntilMs sends null', () async {
      setMockHandler((_) async => null);
      await ProfileChannel().setProfilePaused(11);
      expect(calls.first.method, 'setProfilePaused');
      expect(calls.first.arguments, {'profileId': 11, 'pausedUntilMs': null});
    });

    test('setProfilePaused with pausedUntilMs sends value', () async {
      setMockHandler((_) async => null);
      await ProfileChannel().setProfilePaused(11, pausedUntilMs: 99999);
      expect(calls.first.method, 'setProfilePaused');
      expect(calls.first.arguments,
          {'profileId': 11, 'pausedUntilMs': 99999});
    });

    test('syncAll invokes channel method', () async {
      setMockHandler((_) async => null);
      await ProfileChannel().syncAll();
      expect(calls.first.method, 'syncAll');
      // syncAll has no arguments
      expect(calls.first.arguments, isNull);
    });

    test('multiple calls accumulate in order', () async {
      setMockHandler((_) async => null);
      final c = ProfileChannel();
      await c.notifyProfileChanged(1);
      await c.notifyProfileToggled(profileId: 2, enabled: true);
      await c.syncAll();
      expect(calls.map((m) => m.method).toList(), [
        'notifyProfileChanged',
        'notifyProfileToggled',
        'syncAll',
      ]);
    });
  });
}
