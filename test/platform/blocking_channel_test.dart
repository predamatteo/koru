import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/platform/blocking_channel.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channelName = 'com.koru/blocking';
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

  group('BlockingChannel - lifecycle', () {
    test('startBlockingService invokes native method and returns bool', () async {
      setMockHandler((_) async => true);
      final result = await BlockingChannel().startBlockingService();
      expect(result, isTrue);
      expect(calls, hasLength(1));
      expect(calls.first.method, 'startBlockingService');
    });

    test('startBlockingService returns false when native returns null', () async {
      setMockHandler((_) async => null);
      expect(await BlockingChannel().startBlockingService(), isFalse);
    });

    test('stopBlockingService returns bool', () async {
      setMockHandler((_) async => true);
      expect(await BlockingChannel().stopBlockingService(), isTrue);
      expect(calls.first.method, 'stopBlockingService');
    });

    test('stopBlockingService returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await BlockingChannel().stopBlockingService(), isFalse);
    });

    test('isBlockingServiceRunning returns bool', () async {
      setMockHandler((_) async => true);
      expect(await BlockingChannel().isBlockingServiceRunning(), isTrue);
      expect(calls.first.method, 'isBlockingServiceRunning');
    });

    test('isBlockingServiceRunning returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await BlockingChannel().isBlockingServiceRunning(), isFalse);
    });
  });

  group('BlockingChannel - installed apps', () {
    test('getInstalledApps parses list of maps (label only, no icon)',
        () async {
      setMockHandler((_) async => [
            {
              'packageName': 'com.a',
              'label': 'A',
            },
          ]);
      final result = await BlockingChannel().getInstalledApps();
      expect(result, hasLength(1));
      expect(result.first.packageName, 'com.a');
      expect(result.first.label, 'A');
      expect(calls.first.method, 'getInstalledApps');
    });

    test('getInstalledApps returns empty list when native returns null',
        () async {
      setMockHandler((_) async => null);
      expect(await BlockingChannel().getInstalledApps(), isEmpty);
    });

    test('getInstalledPackageNames returns list', () async {
      setMockHandler((_) async => <String>['com.a', 'com.b']);
      final result = await BlockingChannel().getInstalledPackageNames();
      expect(result, ['com.a', 'com.b']);
      expect(calls.first.method, 'getInstalledPackageNames');
    });

    test('getAppIcon returns the icon bytes for a package', () async {
      final raw = Uint8List.fromList(const [1, 2, 3]);
      setMockHandler((_) async => raw);
      final result = await BlockingChannel().getAppIcon('com.a');
      expect(result, equals(raw));
      expect(calls.first.method, 'getAppIcon');
      expect(calls.first.arguments, {'packageName': 'com.a'});
    });

    test('getAppIcon returns null when native returns null', () async {
      setMockHandler((_) async => null);
      expect(await BlockingChannel().getAppIcon('com.x'), isNull);
    });

    test('getInstalledPackageNames returns const [] when null', () async {
      setMockHandler((_) async => null);
      final result = await BlockingChannel().getInstalledPackageNames();
      expect(result, isEmpty);
    });
  });

  group('BlockingChannel - usage stats', () {
    test('getUsageStats passes start/end ms arguments and parses '
        'AppUsageInfo', () async {
      setMockHandler((_) async => [
            {
              'packageName': 'com.x',
              'totalTimeMs': 1000,
              'lastTimeUsed': 500,
            },
          ]);
      final result = await BlockingChannel().getUsageStats(startMs: 1, endMs: 2);
      expect(result, hasLength(1));
      expect(result.first.packageName, 'com.x');
      expect(result.first.totalTimeMs, 1000);
      expect(result.first.lastTimeUsed, 500);
      expect(calls.first.method, 'getUsageStats');
      expect(calls.first.arguments, {'startMs': 1, 'endMs': 2});
    });

    test('getUsageStats returns empty list when native returns null', () async {
      setMockHandler((_) async => null);
      final result = await BlockingChannel().getUsageStats(startMs: 0, endMs: 0);
      expect(result, isEmpty);
    });

    test('getUsageTodayMs forwards packageName + returns int', () async {
      setMockHandler((_) async => 12345);
      final result = await BlockingChannel().getUsageTodayMs('com.x');
      expect(result, 12345);
      expect(calls.first.method, 'getUsageTodayMs');
      expect(calls.first.arguments, {'packageName': 'com.x'});
    });

    test('getUsageTodayMs returns 0 when native returns null', () async {
      setMockHandler((_) async => null);
      expect(await BlockingChannel().getUsageTodayMs('com.x'), 0);
    });
  });

  group('BlockingChannel - usage stats by day', () {
    test('getUsageStatsByDay passes args and parses DailyUsage list', () async {
      setMockHandler((_) async => [
            {
              'dayStartMs': 1000,
              'apps': [
                {'packageName': 'com.a', 'totalTimeMs': 5000},
                {'packageName': 'com.b', 'totalTimeMs': 2000},
              ],
            },
            {
              'dayStartMs': 2000,
              'apps': <Map<String, Object?>>[],
            },
          ]);
      final result =
          await BlockingChannel().getUsageStatsByDay(startMs: 1, endMs: 9);
      expect(result, hasLength(2));
      expect(result.first.dayStartMs, 1000);
      expect(result.first.apps, hasLength(2));
      expect(result.first.apps.first.packageName, 'com.a');
      expect(result.first.totalMs, 7000);
      expect(result.last.apps, isEmpty);
      expect(result.last.totalMs, 0);
      expect(calls.first.method, 'getUsageStatsByDay');
      expect(calls.first.arguments, {'startMs': 1, 'endMs': 9});
    });

    test('getUsageStatsByDay returns empty list when native returns null',
        () async {
      setMockHandler((_) async => null);
      final result =
          await BlockingChannel().getUsageStatsByDay(startMs: 0, endMs: 0);
      expect(result, isEmpty);
    });
  });

  group('BlockingChannel - quick block / pomodoro', () {
    test('startQuickBlock sends durationMs + whitelist', () async {
      setMockHandler((_) async => true);
      final ok = await BlockingChannel().startQuickBlock(
        const Duration(minutes: 5),
        whitelist: const ['x'],
      );
      expect(ok, isTrue);
      expect(calls.first.method, 'startQuickBlock');
      expect(calls.first.arguments, {
        'durationMs': 300000,
        'whitelist': ['x'],
      });
    });

    test('startQuickBlock returns false on null', () async {
      setMockHandler((_) async => null);
      final ok = await BlockingChannel().startQuickBlock(
        const Duration(minutes: 1),
      );
      expect(ok, isFalse);
    });

    test('stopQuickBlock invokes and returns bool', () async {
      setMockHandler((_) async => true);
      expect(await BlockingChannel().stopQuickBlock(), isTrue);
      expect(calls.first.method, 'stopQuickBlock');
    });

    test('stopQuickBlock returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await BlockingChannel().stopQuickBlock(), isFalse);
    });

    test('startPomodoro forwards workMs/breakMs/cycles + whitelist', () async {
      setMockHandler((_) async => true);
      final ok = await BlockingChannel().startPomodoro(
        workPhase: const Duration(minutes: 25),
        breakPhase: const Duration(minutes: 5),
        cycles: 4,
      );
      expect(ok, isTrue);
      expect(calls.first.method, 'startPomodoro');
      expect(calls.first.arguments, {
        'workMs': 1500000,
        'breakMs': 300000,
        'cycles': 4,
        'whitelist': <String>[],
      });
    });

    test('startPomodoro returns false on null', () async {
      setMockHandler((_) async => null);
      final ok = await BlockingChannel().startPomodoro(
        workPhase: const Duration(minutes: 25),
        breakPhase: const Duration(minutes: 5),
        cycles: 4,
      );
      expect(ok, isFalse);
    });

    test('stopPomodoro invokes and returns bool', () async {
      setMockHandler((_) async => true);
      expect(await BlockingChannel().stopPomodoro(), isTrue);
      expect(calls.first.method, 'stopPomodoro');
    });
  });

  group('BlockingChannel - app actions', () {
    test('launchApp passes packageName', () async {
      setMockHandler((_) async => true);
      expect(await BlockingChannel().launchApp('com.x'), isTrue);
      expect(calls.first.method, 'launchApp');
      expect(calls.first.arguments, {'packageName': 'com.x'});
    });

    test('launchApp returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await BlockingChannel().launchApp('com.x'), isFalse);
    });

    test('uninstallApp passes packageName', () async {
      setMockHandler((_) async => true);
      expect(await BlockingChannel().uninstallApp('com.x'), isTrue);
      expect(calls.first.method, 'uninstallApp');
      expect(calls.first.arguments, {'packageName': 'com.x'});
    });

    test('openAppInfo passes packageName', () async {
      setMockHandler((_) async => true);
      expect(await BlockingChannel().openAppInfo('com.x'), isTrue);
      expect(calls.first.method, 'openAppInfo');
      expect(calls.first.arguments, {'packageName': 'com.x'});
    });
  });

  group('BlockingChannel - device info', () {
    test('getBatteryLevel returns -1 on null', () async {
      setMockHandler((_) async => null);
      expect(await BlockingChannel().getBatteryLevel(), -1);
    });

    test('getBatteryLevel returns native value', () async {
      setMockHandler((_) async => 76);
      expect(await BlockingChannel().getBatteryLevel(), 76);
      expect(calls.first.method, 'getBatteryLevel');
    });

    test('isCharging returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await BlockingChannel().isCharging(), isFalse);
    });

    test('isCharging returns native bool', () async {
      setMockHandler((_) async => true);
      expect(await BlockingChannel().isCharging(), isTrue);
    });

    test('getDefaultDialerPackage forwards string or null', () async {
      setMockHandler((_) async => 'com.dialer');
      expect(await BlockingChannel().getDefaultDialerPackage(), 'com.dialer');

      clearMockHandler();
      calls = [];
      setMockHandler((_) async => null);
      expect(await BlockingChannel().getDefaultDialerPackage(), isNull);
    });

    test('getDefaultCameraPackage forwards string or null', () async {
      setMockHandler((_) async => 'com.camera');
      expect(await BlockingChannel().getDefaultCameraPackage(), 'com.camera');

      clearMockHandler();
      calls = [];
      setMockHandler((_) async => null);
      expect(await BlockingChannel().getDefaultCameraPackage(), isNull);
    });

    test('getCurrentWifiSsid forwards string or null', () async {
      setMockHandler((_) async => 'Home_Wifi');
      expect(await BlockingChannel().getCurrentWifiSsid(), 'Home_Wifi');

      clearMockHandler();
      calls = [];
      setMockHandler((_) async => null);
      expect(await BlockingChannel().getCurrentWifiSsid(), isNull);
    });
  });

  group('BlockingChannel - daily limits', () {
    test('getAppDailyLimits parses legacy int format as strict=true', () async {
      setMockHandler((_) async => <String, dynamic>{'com.x': 30});
      final result = await BlockingChannel().getAppDailyLimits();
      expect(result, hasLength(1));
      expect(result['com.x']!.minutes, 30);
      expect(result['com.x']!.strict, isTrue);
    });

    test('getAppDailyLimits parses new map format', () async {
      setMockHandler((_) async => <String, dynamic>{
            'com.x': {'minutes': 45, 'strict': false},
          });
      final result = await BlockingChannel().getAppDailyLimits();
      expect(result['com.x']!.minutes, 45);
      expect(result['com.x']!.strict, isFalse);
    });

    test('getAppDailyLimits excludes entries with minutes <= 0', () async {
      setMockHandler((_) async => <String, dynamic>{'com.x': 0});
      final result = await BlockingChannel().getAppDailyLimits();
      expect(result, isEmpty);
    });

    test('getAppDailyLimits returns const {} on null', () async {
      setMockHandler((_) async => null);
      final result = await BlockingChannel().getAppDailyLimits();
      expect(result, isEmpty);
    });

    test('setAppDailyLimits serializes config map', () async {
      setMockHandler((_) async => true);
      final ok = await BlockingChannel().setAppDailyLimits({
        'com.x': const AppLimitConfig(minutes: 60, strict: true),
      });
      expect(ok, isTrue);
      expect(calls.first.method, 'setAppDailyLimits');
      final args = calls.first.arguments as Map;
      expect(args['limits'], {
        'com.x': {'minutes': 60, 'strict': true},
      });
    });

    test('setAppDailyLimits returns false on null', () async {
      setMockHandler((_) async => null);
      final ok =
          await BlockingChannel().setAppDailyLimits(const {});
      expect(ok, isFalse);
    });

    test('setAppDailyLimits propagates native false (CR-09 save failed)',
        () async {
      // CR-09: il nativo ora ritorna il vero esito della scrittura atomica
      // dello store (Boolean). Quando lo store fallisce e risponde `false`,
      // il facade Dart DEVE propagare `false`, non assumere il successo.
      setMockHandler((_) async => false);
      final ok = await BlockingChannel().setAppDailyLimits({
        'com.x': const AppLimitConfig(minutes: 60, strict: true),
      });
      expect(ok, isFalse);
      expect(calls.first.method, 'setAppDailyLimits');
    });

    test('setAppDailyLimits returns true when native save succeeds', () async {
      setMockHandler((_) async => true);
      final ok = await BlockingChannel().setAppDailyLimits({
        'com.x': const AppLimitConfig(minutes: 60, strict: true),
      });
      expect(ok, isTrue);
    });
  });

  group('BlockingChannel - bypass counter', () {
    test('getBypassCountToday passes packageName + returns int', () async {
      setMockHandler((_) async => 7);
      final result = await BlockingChannel().getBypassCountToday('com.x');
      expect(result, 7);
      expect(calls.first.method, 'getBypassCountToday');
      expect(calls.first.arguments, {'packageName': 'com.x'});
    });

    test('getBypassCountToday returns 0 on null', () async {
      setMockHandler((_) async => null);
      expect(await BlockingChannel().getBypassCountToday('com.x'), 0);
    });

    test('resetBypassCount invokes without errors', () async {
      setMockHandler((_) async => true);
      await BlockingChannel().resetBypassCount('com.x');
      expect(calls.first.method, 'resetBypassCount');
      expect(calls.first.arguments, {'packageName': 'com.x'});
    });
  });

  group('BlockingChannel - notifications', () {
    test('getSilencedPackages returns list', () async {
      setMockHandler((_) async => <String>['a', 'b']);
      final result = await BlockingChannel().getSilencedPackages();
      expect(result, ['a', 'b']);
      expect(calls.first.method, 'getSilencedPackages');
    });

    test('getSilencedPackages returns const [] when null', () async {
      setMockHandler((_) async => null);
      expect(await BlockingChannel().getSilencedPackages(), isEmpty);
    });

    test('setSilencedPackages passes packages list', () async {
      setMockHandler((_) async => true);
      final ok = await BlockingChannel().setSilencedPackages(['a', 'b']);
      expect(ok, isTrue);
      expect(calls.first.method, 'setSilencedPackages');
      expect(calls.first.arguments, {
        'packages': ['a', 'b'],
      });
    });

    test('setSilencedPackages returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await BlockingChannel().setSilencedPackages([]), isFalse);
    });

    test('setSilencedPackages propagates native false (CR-09 save failed)',
        () async {
      // CR-09: come setAppDailyLimits, il nativo ritorna l'esito reale della
      // scrittura atomica. `false` ⇒ il facade Dart propaga `false`.
      setMockHandler((_) async => false);
      final ok = await BlockingChannel().setSilencedPackages(['a', 'b']);
      expect(ok, isFalse);
      expect(calls.first.method, 'setSilencedPackages');
    });

    test('setSilencedPackages returns true when native save succeeds', () async {
      setMockHandler((_) async => true);
      expect(await BlockingChannel().setSilencedPackages(['a']), isTrue);
    });

    test('isNotificationAccessGranted returns bool', () async {
      setMockHandler((_) async => true);
      expect(await BlockingChannel().isNotificationAccessGranted(), isTrue);
      expect(calls.first.method, 'isNotificationAccessGranted');
    });

    test('isNotificationAccessGranted returns false on null', () async {
      setMockHandler((_) async => null);
      expect(await BlockingChannel().isNotificationAccessGranted(), isFalse);
    });

    test('openNotificationAccessSettings invokes channel method', () async {
      setMockHandler((_) async => true);
      await BlockingChannel().openNotificationAccessSettings();
      expect(calls.first.method, 'openNotificationAccessSettings');
    });
  });

  group('InstalledAppInfo.fromMap', () {
    test('parses packageName and label', () {
      final info = InstalledAppInfo.fromMap(<dynamic, dynamic>{
        'packageName': 'com.a',
        'label': 'A',
      });
      expect(info.packageName, 'com.a');
      expect(info.label, 'A');
    });

    test('tolerates extra fields (icon no longer part of the contract)', () {
      // getInstalledApps non trasporta più le icone (decode lazy via
      // getAppIcon): fromMap deve restare tollerante a eventuali campi extra
      // senza rompersi.
      final info = InstalledAppInfo.fromMap(<dynamic, dynamic>{
        'packageName': 'com.b',
        'label': 'B',
        'icon': <int>[9, 8, 7],
        'isLauncher': false,
      });
      expect(info.packageName, 'com.b');
      expect(info.label, 'B');
    });
  });

  group('AppLimitConfig', () {
    test('fromAny(int 30) → strict=true, minutes=30', () {
      final cfg = AppLimitConfig.fromAny(30);
      expect(cfg, isNotNull);
      expect(cfg!.minutes, 30);
      expect(cfg.strict, isTrue);
    });

    test('fromAny(int 0) → null', () {
      expect(AppLimitConfig.fromAny(0), isNull);
    });

    test('fromAny(negative int) → null', () {
      expect(AppLimitConfig.fromAny(-5), isNull);
    });

    test('fromAny(Map minutes:45 only) → strict default true', () {
      final cfg = AppLimitConfig.fromAny(<String, dynamic>{'minutes': 45});
      expect(cfg, isNotNull);
      expect(cfg!.minutes, 45);
      expect(cfg.strict, isTrue);
    });

    test('fromAny(Map minutes:45, strict:false)', () {
      final cfg = AppLimitConfig.fromAny(
        <String, dynamic>{'minutes': 45, 'strict': false},
      );
      expect(cfg, isNotNull);
      expect(cfg!.minutes, 45);
      expect(cfg.strict, isFalse);
    });

    test('fromAny(Map minutes:0) → null', () {
      expect(
        AppLimitConfig.fromAny(<String, dynamic>{'minutes': 0}),
        isNull,
      );
    });

    test('fromAny(garbage string) → null', () {
      expect(AppLimitConfig.fromAny('garbage'), isNull);
    });

    test('fromAny(null) → null', () {
      expect(AppLimitConfig.fromAny(null), isNull);
    });

    test('toMap roundtrip via fromAny', () {
      const cfg = AppLimitConfig(minutes: 12, strict: false);
      final map = cfg.toMap();
      expect(map, {'minutes': 12, 'strict': false});
      final round = AppLimitConfig.fromAny(map);
      expect(round, isNotNull);
      expect(round!.minutes, 12);
      expect(round.strict, isFalse);
    });

    test('copyWith overrides minutes', () {
      const cfg = AppLimitConfig(minutes: 30, strict: false);
      final updated = cfg.copyWith(minutes: 60);
      expect(updated.minutes, 60);
      expect(updated.strict, isFalse);
    });

    test('copyWith overrides strict', () {
      const cfg = AppLimitConfig(minutes: 30, strict: false);
      final updated = cfg.copyWith(strict: true);
      expect(updated.minutes, 30);
      expect(updated.strict, isTrue);
    });

    test('copyWith without args returns equivalent config', () {
      const cfg = AppLimitConfig(minutes: 30, strict: false);
      final updated = cfg.copyWith();
      expect(updated.minutes, cfg.minutes);
      expect(updated.strict, cfg.strict);
    });
  });

  group('AppUsageInfo.fromMap', () {
    test('parses packageName, totalTimeMs, lastTimeUsed', () {
      final info = AppUsageInfo.fromMap(<dynamic, dynamic>{
        'packageName': 'com.x',
        'totalTimeMs': 1000,
        'lastTimeUsed': 500,
      });
      expect(info.packageName, 'com.x');
      expect(info.totalTimeMs, 1000);
      expect(info.lastTimeUsed, 500);
    });

    test('coerces num values via toInt()', () {
      final info = AppUsageInfo.fromMap(<dynamic, dynamic>{
        'packageName': 'com.x',
        'totalTimeMs': 1000.7,
        'lastTimeUsed': 500.4,
      });
      expect(info.totalTimeMs, 1000);
      expect(info.lastTimeUsed, 500);
    });
  });

  group('DailyUsage.fromMap', () {
    test('parses dayStartMs and apps, sums totalMs', () {
      final d = DailyUsage.fromMap(<dynamic, dynamic>{
        'dayStartMs': 1234,
        'apps': [
          {'packageName': 'com.a', 'totalTimeMs': 1000},
          {'packageName': 'com.b', 'totalTimeMs': 500},
        ],
      });
      expect(d.dayStartMs, 1234);
      expect(d.apps, hasLength(2));
      expect(d.apps.first.packageName, 'com.a');
      expect(d.apps.first.lastTimeUsed, 0);
      expect(d.totalMs, 1500);
    });

    test('handles missing apps as empty', () {
      final d = DailyUsage.fromMap(<dynamic, dynamic>{'dayStartMs': 5});
      expect(d.apps, isEmpty);
      expect(d.totalMs, 0);
    });

    test('coerces num totalTimeMs via toInt()', () {
      final d = DailyUsage.fromMap(<dynamic, dynamic>{
        'dayStartMs': 0,
        'apps': [
          {'packageName': 'com.a', 'totalTimeMs': 1000.9},
        ],
      });
      expect(d.apps.first.totalTimeMs, 1000);
    });
  });
}
