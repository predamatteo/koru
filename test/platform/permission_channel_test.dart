import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/platform/permission_channel.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channelName = 'com.koru/permissions';
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

  group('PermissionChannel - accessibility', () {
    test('checkAccessibilityService returns native bool', () async {
      setMockHandler((_) async => true);
      expect(await PermissionChannel().checkAccessibilityService(), isTrue);
      expect(calls.first.method, 'checkAccessibilityService');
    });

    test('checkAccessibilityService returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await PermissionChannel().checkAccessibilityService(), isFalse);
    });

    test('openAccessibilitySettings invokes channel method', () async {
      setMockHandler((_) async => null);
      await PermissionChannel().openAccessibilitySettings();
      expect(calls.first.method, 'openAccessibilitySettings');
    });
  });

  group('PermissionChannel - usage stats', () {
    test('checkUsageStatsPermission returns bool', () async {
      setMockHandler((_) async => true);
      expect(await PermissionChannel().checkUsageStatsPermission(), isTrue);
      expect(calls.first.method, 'checkUsageStatsPermission');
    });

    test('checkUsageStatsPermission returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await PermissionChannel().checkUsageStatsPermission(), isFalse);
    });

    test('openUsageStatsSettings invokes channel method', () async {
      setMockHandler((_) async => null);
      await PermissionChannel().openUsageStatsSettings();
      expect(calls.first.method, 'openUsageStatsSettings');
    });
  });

  group('PermissionChannel - overlay', () {
    test('checkOverlayPermission returns bool', () async {
      setMockHandler((_) async => true);
      expect(await PermissionChannel().checkOverlayPermission(), isTrue);
      expect(calls.first.method, 'checkOverlayPermission');
    });

    test('checkOverlayPermission returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await PermissionChannel().checkOverlayPermission(), isFalse);
    });

    test('openOverlaySettings invokes channel method', () async {
      setMockHandler((_) async => null);
      await PermissionChannel().openOverlaySettings();
      expect(calls.first.method, 'openOverlaySettings');
    });
  });

  group('PermissionChannel - battery optimization', () {
    test('checkBatteryOptimization returns bool', () async {
      setMockHandler((_) async => true);
      expect(await PermissionChannel().checkBatteryOptimization(), isTrue);
      expect(calls.first.method, 'checkBatteryOptimization');
    });

    test('checkBatteryOptimization returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await PermissionChannel().checkBatteryOptimization(), isFalse);
    });

    test('requestDisableBatteryOptimization invokes channel method', () async {
      setMockHandler((_) async => null);
      await PermissionChannel().requestDisableBatteryOptimization();
      expect(calls.first.method, 'requestDisableBatteryOptimization');
    });
  });

  group('PermissionChannel - notification listener', () {
    test('checkNotificationListener returns bool', () async {
      setMockHandler((_) async => true);
      expect(await PermissionChannel().checkNotificationListener(), isTrue);
      expect(calls.first.method, 'checkNotificationListener');
    });

    test('checkNotificationListener returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await PermissionChannel().checkNotificationListener(), isFalse);
    });

    test('openNotificationListenerSettings invokes channel method', () async {
      setMockHandler((_) async => null);
      await PermissionChannel().openNotificationListenerSettings();
      expect(calls.first.method, 'openNotificationListenerSettings');
    });
  });

  group('PermissionChannel - launcher', () {
    test('isDefaultLauncher returns bool', () async {
      setMockHandler((_) async => true);
      expect(await PermissionChannel().isDefaultLauncher(), isTrue);
      expect(calls.first.method, 'isDefaultLauncher');
    });

    test('isDefaultLauncher returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await PermissionChannel().isDefaultLauncher(), isFalse);
    });

    test('openDefaultLauncherSettings invokes channel method', () async {
      setMockHandler((_) async => null);
      await PermissionChannel().openDefaultLauncherSettings();
      expect(calls.first.method, 'openDefaultLauncherSettings');
    });

    test('setLauncherModeEnabled(true) sends enabled arg', () async {
      setMockHandler((_) async => true);
      final ok = await PermissionChannel().setLauncherModeEnabled(true);
      expect(ok, isTrue);
      expect(calls.first.method, 'setLauncherModeEnabled');
      expect(calls.first.arguments, {'enabled': true});
    });

    test('setLauncherModeEnabled(false) sends enabled arg', () async {
      setMockHandler((_) async => false);
      final ok = await PermissionChannel().setLauncherModeEnabled(false);
      expect(ok, isFalse);
      expect(calls.first.arguments, {'enabled': false});
    });

    test('setLauncherModeEnabled returns false on null', () async {
      setMockHandler((_) async => null);
      expect(
        await PermissionChannel().setLauncherModeEnabled(true),
        isFalse,
      );
    });

    test('isLauncherModeEnabled returns bool', () async {
      setMockHandler((_) async => true);
      expect(await PermissionChannel().isLauncherModeEnabled(), isTrue);
      expect(calls.first.method, 'isLauncherModeEnabled');
    });

    test('isLauncherModeEnabled returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await PermissionChannel().isLauncherModeEnabled(), isFalse);
    });

    test('setLauncherRecentsShield sends enabled arg', () async {
      setMockHandler((_) async => null);
      await PermissionChannel().setLauncherRecentsShield(true);
      expect(calls.first.method, 'setLauncherRecentsShield');
      expect(calls.first.arguments, {'enabled': true});

      await PermissionChannel().setLauncherRecentsShield(false);
      expect(calls.last.arguments, {'enabled': false});
    });
  });

  group('PermissionChannel - checkAllPermissions', () {
    test('parses full status map', () async {
      setMockHandler((_) async => <String, dynamic>{
            'accessibility': true,
            'usageStats': true,
            'overlay': true,
            'battery': true,
            'notificationListener': true,
            'defaultLauncher': true,
          });
      final status = await PermissionChannel().checkAllPermissions();
      expect(status.accessibility, isTrue);
      expect(status.usageStats, isTrue);
      expect(status.overlay, isTrue);
      expect(status.batteryOptimizationIgnored, isTrue);
      expect(status.notificationListener, isTrue);
      expect(status.defaultLauncher, isTrue);
      expect(status.allMandatoryGranted, isTrue);
      expect(calls.first.method, 'checkAllPermissions');
    });

    test('null native response → all false', () async {
      setMockHandler((_) async => null);
      final status = await PermissionChannel().checkAllPermissions();
      expect(status.accessibility, isFalse);
      expect(status.usageStats, isFalse);
      expect(status.overlay, isFalse);
      expect(status.batteryOptimizationIgnored, isFalse);
      expect(status.notificationListener, isFalse);
      expect(status.defaultLauncher, isFalse);
      expect(status.allMandatoryGranted, isFalse);
    });

    test('partial map preserves missing keys as false', () async {
      setMockHandler((_) async => <String, dynamic>{
            'accessibility': true,
            'overlay': true,
          });
      final status = await PermissionChannel().checkAllPermissions();
      expect(status.accessibility, isTrue);
      expect(status.usageStats, isFalse);
      expect(status.overlay, isTrue);
      expect(status.batteryOptimizationIgnored, isFalse);
      expect(status.notificationListener, isFalse);
      expect(status.defaultLauncher, isFalse);
      expect(status.allMandatoryGranted, isFalse);
    });
  });

  group('KoruPermissionStatus.allMandatoryGranted', () {
    KoruPermissionStatus statusWith({
      bool accessibility = false,
      bool usageStats = false,
      bool overlay = false,
      bool batteryOptimizationIgnored = false,
      bool notificationListener = false,
      bool defaultLauncher = false,
    }) {
      return KoruPermissionStatus(
        accessibility: accessibility,
        usageStats: usageStats,
        overlay: overlay,
        batteryOptimizationIgnored: batteryOptimizationIgnored,
        notificationListener: notificationListener,
        defaultLauncher: defaultLauncher,
      );
    }

    test('true only when accessibility + usageStats + overlay all true', () {
      expect(
        statusWith(
          accessibility: true,
          usageStats: true,
          overlay: true,
        ).allMandatoryGranted,
        isTrue,
      );
    });

    test('false when accessibility is false', () {
      expect(
        statusWith(usageStats: true, overlay: true).allMandatoryGranted,
        isFalse,
      );
    });

    test('false when usageStats is false', () {
      expect(
        statusWith(accessibility: true, overlay: true).allMandatoryGranted,
        isFalse,
      );
    });

    test('false when overlay is false', () {
      expect(
        statusWith(accessibility: true, usageStats: true).allMandatoryGranted,
        isFalse,
      );
    });

    test('battery / notification / launcher do NOT affect mandatory gate', () {
      expect(
        statusWith(
          accessibility: true,
          usageStats: true,
          overlay: true,
          batteryOptimizationIgnored: false,
          notificationListener: false,
          defaultLauncher: false,
        ).allMandatoryGranted,
        isTrue,
      );
    });
  });
}
