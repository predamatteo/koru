import 'package:flutter/services.dart';

class InstalledAppInfo {
  InstalledAppInfo({
    required this.packageName,
    required this.label,
    this.iconBytes,
  });

  final String packageName;
  final String label;
  final Uint8List? iconBytes;

  factory InstalledAppInfo.fromMap(Map<dynamic, dynamic> map) {
    final iconRaw = map['icon'];
    return InstalledAppInfo(
      packageName: map['packageName'] as String,
      label: map['label'] as String,
      iconBytes: iconRaw is List<dynamic>
          ? Uint8List.fromList(iconRaw.cast<int>())
          : (iconRaw as Uint8List?),
    );
  }
}

class AppUsageInfo {
  AppUsageInfo({
    required this.packageName,
    required this.totalTimeMs,
    required this.lastTimeUsed,
  });

  final String packageName;
  final int totalTimeMs;
  final int lastTimeUsed;

  factory AppUsageInfo.fromMap(Map<dynamic, dynamic> map) => AppUsageInfo(
        packageName: map['packageName'] as String,
        totalTimeMs: (map['totalTimeMs'] as num).toInt(),
        lastTimeUsed: (map['lastTimeUsed'] as num).toInt(),
      );
}

/// Flutter-side facade per com.koru/blocking MethodChannel.
class BlockingChannel {
  BlockingChannel();

  static const _channel = MethodChannel('com.koru/blocking');

  Future<bool> startBlockingService() async =>
      (await _channel.invokeMethod<bool>('startBlockingService')) ?? false;

  Future<bool> stopBlockingService() async =>
      (await _channel.invokeMethod<bool>('stopBlockingService')) ?? false;

  Future<bool> isBlockingServiceRunning() async =>
      (await _channel.invokeMethod<bool>('isBlockingServiceRunning')) ?? false;

  Future<List<InstalledAppInfo>> getInstalledApps() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
    if (raw == null) return const [];
    return raw
        .cast<Map<dynamic, dynamic>>()
        .map(InstalledAppInfo.fromMap)
        .toList(growable: false);
  }

  Future<List<AppUsageInfo>> getUsageStats({
    required int startMs,
    required int endMs,
  }) async {
    final raw = await _channel.invokeMethod<List<dynamic>>('getUsageStats', {
      'startMs': startMs,
      'endMs': endMs,
    });
    if (raw == null) return const [];
    return raw
        .cast<Map<dynamic, dynamic>>()
        .map(AppUsageInfo.fromMap)
        .toList(growable: false);
  }

  Future<bool> startQuickBlock(
    Duration duration, {
    List<String> whitelist = const [],
  }) async =>
      (await _channel.invokeMethod<bool>('startQuickBlock', {
        'durationMs': duration.inMilliseconds,
        'whitelist': whitelist,
      })) ??
      false;

  Future<bool> stopQuickBlock() async =>
      (await _channel.invokeMethod<bool>('stopQuickBlock')) ?? false;

  Future<bool> startPomodoro({
    required Duration workPhase,
    required Duration breakPhase,
    required int cycles,
    List<String> whitelist = const [],
  }) async =>
      (await _channel.invokeMethod<bool>('startPomodoro', {
        'workMs': workPhase.inMilliseconds,
        'breakMs': breakPhase.inMilliseconds,
        'cycles': cycles,
        'whitelist': whitelist,
      })) ??
      false;

  Future<bool> stopPomodoro() async =>
      (await _channel.invokeMethod<bool>('stopPomodoro')) ?? false;

  Future<bool> launchApp(String packageName) async =>
      (await _channel.invokeMethod<bool>('launchApp', {
        'packageName': packageName,
      })) ??
      false;

  Future<int> getBatteryLevel() async =>
      (await _channel.invokeMethod<int>('getBatteryLevel')) ?? -1;

  Future<bool> isCharging() async =>
      (await _channel.invokeMethod<bool>('isCharging')) ?? false;

  Future<String?> getDefaultDialerPackage() async =>
      _channel.invokeMethod<String>('getDefaultDialerPackage');

  Future<String?> getDefaultCameraPackage() async =>
      _channel.invokeMethod<String>('getDefaultCameraPackage');

  Future<Map<String, int>> getAppDailyLimits() async {
    final raw = await _channel
        .invokeMapMethod<String, dynamic>('getAppDailyLimits');
    if (raw == null) return const {};
    return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  Future<bool> setAppDailyLimits(Map<String, int> limits) async =>
      (await _channel.invokeMethod<bool>('setAppDailyLimits', {
        'limits': limits,
      })) ??
      false;

  Future<int> getUsageTodayMs(String packageName) async =>
      (await _channel.invokeMethod<int>('getUsageTodayMs', {
        'packageName': packageName,
      })) ??
      0;
}
