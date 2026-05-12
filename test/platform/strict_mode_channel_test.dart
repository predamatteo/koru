import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/platform/strict_mode_channel.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channelName = 'com.koru/strict_mode';
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

  group('StrictModeOption bit flags', () {
    test('values match Kotlin contract', () {
      expect(StrictModeOption.blockEditing, 1);
      expect(StrictModeOption.blockSettings, 2);
      expect(StrictModeOption.blockUninstalling, 4);
      expect(StrictModeOption.blockRecentApps, 8);
      expect(StrictModeOption.blockSplitScreen, 16);
    });

    test('allMvp = blockSettings | blockUninstalling | blockRecentApps = 14',
        () {
      const expected = StrictModeOption.blockSettings |
          StrictModeOption.blockUninstalling |
          StrictModeOption.blockRecentApps;
      expect(StrictModeOption.allMvp, expected);
      expect(StrictModeOption.allMvp, 14);
    });
  });

  group('BackdoorOutcome', () {
    test('BackdoorValid is const-constructible', () {
      const a = BackdoorValid();
      const b = BackdoorValid();
      expect(identical(a, b), isTrue);
    });

    test('BackdoorInvalid is const-constructible', () {
      const a = BackdoorInvalid();
      const b = BackdoorInvalid();
      expect(identical(a, b), isTrue);
    });

    test('BackdoorReplay is const-constructible', () {
      const a = BackdoorReplay();
      const b = BackdoorReplay();
      expect(identical(a, b), isTrue);
    });

    test('BackdoorLocked stores remainingMs', () {
      const locked = BackdoorLocked(5000);
      expect(locked.remainingMs, 5000);
    });
  });

  group('StrictModeChannel - device admin', () {
    test('enableDeviceAdmin returns native bool', () async {
      setMockHandler((_) async => true);
      expect(await StrictModeChannel().enableDeviceAdmin(), isTrue);
      expect(calls.first.method, 'enableDeviceAdmin');
    });

    test('enableDeviceAdmin returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await StrictModeChannel().enableDeviceAdmin(), isFalse);
    });

    test('disableDeviceAdmin returns bool', () async {
      setMockHandler((_) async => true);
      expect(await StrictModeChannel().disableDeviceAdmin(), isTrue);
      expect(calls.first.method, 'disableDeviceAdmin');
    });

    test('disableDeviceAdmin returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await StrictModeChannel().disableDeviceAdmin(), isFalse);
    });

    test('isDeviceAdminActive returns bool', () async {
      setMockHandler((_) async => true);
      expect(await StrictModeChannel().isDeviceAdminActive(), isTrue);
      expect(calls.first.method, 'isDeviceAdminActive');
    });

    test('isDeviceAdminActive returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await StrictModeChannel().isDeviceAdminActive(), isFalse);
    });
  });

  group('StrictModeChannel - options bitmask', () {
    test('setStrictModeOptions sends mask argument', () async {
      setMockHandler((_) async => null);
      await StrictModeChannel().setStrictModeOptions(15);
      expect(calls.first.method, 'setStrictModeOptions');
      expect(calls.first.arguments, {'mask': 15});
    });

    test('getStrictModeOptions returns int', () async {
      setMockHandler((_) async => 14);
      expect(await StrictModeChannel().getStrictModeOptions(), 14);
      expect(calls.first.method, 'getStrictModeOptions');
    });

    test('getStrictModeOptions returns 0 on null', () async {
      setMockHandler((_) async => null);
      expect(await StrictModeChannel().getStrictModeOptions(), 0);
    });
  });

  group('StrictModeChannel - backdoor generate', () {
    test('generateBackdoorCode returns string', () async {
      setMockHandler((_) async => 'ABCD1234');
      expect(await StrictModeChannel().generateBackdoorCode(), 'ABCD1234');
      expect(calls.first.method, 'generateBackdoorCode');
    });

    test('generateBackdoorCode returns empty string on null', () async {
      setMockHandler((_) async => null);
      expect(await StrictModeChannel().generateBackdoorCode(), '');
    });
  });

  group('StrictModeChannel - validateBackdoorCode', () {
    test('native true → BackdoorValid', () async {
      setMockHandler((_) async => true);
      final result =
          await StrictModeChannel().validateBackdoorCode('ABCD1234');
      expect(result, isA<BackdoorValid>());
      expect(calls.first.method, 'validateBackdoorCode');
      expect(calls.first.arguments, {'code': 'ABCD1234'});
    });

    test('native false → BackdoorInvalid', () async {
      setMockHandler((_) async => false);
      final result =
          await StrictModeChannel().validateBackdoorCode('ABCD1234');
      expect(result, isA<BackdoorInvalid>());
    });

    test('native null → BackdoorInvalid', () async {
      setMockHandler((_) async => null);
      final result =
          await StrictModeChannel().validateBackdoorCode('ABCD1234');
      expect(result, isA<BackdoorInvalid>());
    });

    test('PlatformException(LOCKED_OUT) with int details → '
        'BackdoorLocked(ms)', () async {
      setMockHandler((_) async {
        throw PlatformException(code: 'LOCKED_OUT', details: 30000);
      });
      final result =
          await StrictModeChannel().validateBackdoorCode('ABCD1234');
      expect(result, isA<BackdoorLocked>());
      expect((result as BackdoorLocked).remainingMs, 30000);
    });

    test('PlatformException(LOCKED_OUT) with non-int details → '
        'BackdoorLocked(0)', () async {
      setMockHandler((_) async {
        throw PlatformException(code: 'LOCKED_OUT', details: 'not-an-int');
      });
      final result =
          await StrictModeChannel().validateBackdoorCode('ABCD1234');
      expect(result, isA<BackdoorLocked>());
      expect((result as BackdoorLocked).remainingMs, 0);
    });

    test('PlatformException(REPLAY) → BackdoorReplay', () async {
      setMockHandler((_) async {
        throw PlatformException(code: 'REPLAY');
      });
      final result =
          await StrictModeChannel().validateBackdoorCode('ABCD1234');
      expect(result, isA<BackdoorReplay>());
    });

    test('PlatformException(OTHER) → BackdoorInvalid', () async {
      setMockHandler((_) async {
        throw PlatformException(code: 'OTHER');
      });
      final result =
          await StrictModeChannel().validateBackdoorCode('ABCD1234');
      expect(result, isA<BackdoorInvalid>());
    });
  });

  group('StrictModeChannel - performEmergencyUnblock', () {
    test('native true → BackdoorValid', () async {
      setMockHandler((_) async => true);
      final result =
          await StrictModeChannel().performEmergencyUnblock('CODE');
      expect(result, isA<BackdoorValid>());
      expect(calls.first.method, 'performEmergencyUnblock');
      expect(calls.first.arguments, {'code': 'CODE'});
    });

    test('native false → BackdoorInvalid', () async {
      setMockHandler((_) async => false);
      final result =
          await StrictModeChannel().performEmergencyUnblock('CODE');
      expect(result, isA<BackdoorInvalid>());
    });

    test('native null → BackdoorInvalid', () async {
      setMockHandler((_) async => null);
      final result =
          await StrictModeChannel().performEmergencyUnblock('CODE');
      expect(result, isA<BackdoorInvalid>());
    });

    test('PlatformException(INVALID_CODE) → BackdoorInvalid', () async {
      setMockHandler((_) async {
        throw PlatformException(code: 'INVALID_CODE');
      });
      final result =
          await StrictModeChannel().performEmergencyUnblock('CODE');
      expect(result, isA<BackdoorInvalid>());
    });

    test('PlatformException(LOCKED_OUT) → BackdoorLocked(ms)', () async {
      setMockHandler((_) async {
        throw PlatformException(code: 'LOCKED_OUT', details: 1000);
      });
      final result =
          await StrictModeChannel().performEmergencyUnblock('CODE');
      expect(result, isA<BackdoorLocked>());
      expect((result as BackdoorLocked).remainingMs, 1000);
    });

    test('PlatformException(LOCKED_OUT) non-int details → '
        'BackdoorLocked(0)', () async {
      setMockHandler((_) async {
        throw PlatformException(code: 'LOCKED_OUT', details: null);
      });
      final result =
          await StrictModeChannel().performEmergencyUnblock('CODE');
      expect(result, isA<BackdoorLocked>());
      expect((result as BackdoorLocked).remainingMs, 0);
    });

    test('PlatformException(REPLAY) → BackdoorReplay', () async {
      setMockHandler((_) async {
        throw PlatformException(code: 'REPLAY');
      });
      final result =
          await StrictModeChannel().performEmergencyUnblock('CODE');
      expect(result, isA<BackdoorReplay>());
    });

    test('PlatformException(UNKNOWN) → BackdoorInvalid', () async {
      setMockHandler((_) async {
        throw PlatformException(code: 'UNKNOWN');
      });
      final result =
          await StrictModeChannel().performEmergencyUnblock('CODE');
      expect(result, isA<BackdoorInvalid>());
    });
  });

  group('StrictModeChannel - state introspection', () {
    test('getRemainingAttempts returns int', () async {
      setMockHandler((_) async => 3);
      expect(await StrictModeChannel().getRemainingAttempts(), 3);
      expect(calls.first.method, 'getRemainingAttempts');
    });

    test('getRemainingAttempts returns 0 on null', () async {
      setMockHandler((_) async => null);
      expect(await StrictModeChannel().getRemainingAttempts(), 0);
    });

    test('getLockoutRemainingMs returns int', () async {
      setMockHandler((_) async => 60000);
      expect(await StrictModeChannel().getLockoutRemainingMs(), 60000);
      expect(calls.first.method, 'getLockoutRemainingMs');
    });

    test('getLockoutRemainingMs returns 0 on null', () async {
      setMockHandler((_) async => null);
      expect(await StrictModeChannel().getLockoutRemainingMs(), 0);
    });

    test('isStrictModeActive returns bool', () async {
      setMockHandler((_) async => true);
      expect(await StrictModeChannel().isStrictModeActive(), isTrue);
      expect(calls.first.method, 'isStrictModeActive');
    });

    test('isStrictModeActive returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await StrictModeChannel().isStrictModeActive(), isFalse);
    });
  });
}
