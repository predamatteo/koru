import 'package:flutter/services.dart';

class KoruPermissionStatus {
  const KoruPermissionStatus({
    required this.accessibility,
    required this.usageStats,
    required this.overlay,
    required this.batteryOptimizationIgnored,
    required this.notificationListener,
    required this.defaultLauncher,
  });

  final bool accessibility;
  final bool usageStats;
  final bool overlay;
  final bool batteryOptimizationIgnored;
  final bool notificationListener;
  final bool defaultLauncher;

  bool get allMandatoryGranted => accessibility && usageStats && overlay;

  factory KoruPermissionStatus.fromMap(Map<dynamic, dynamic> map) =>
      KoruPermissionStatus(
        accessibility: map['accessibility'] as bool? ?? false,
        usageStats: map['usageStats'] as bool? ?? false,
        overlay: map['overlay'] as bool? ?? false,
        batteryOptimizationIgnored: map['battery'] as bool? ?? false,
        notificationListener: map['notificationListener'] as bool? ?? false,
        defaultLauncher: map['defaultLauncher'] as bool? ?? false,
      );
}

class PermissionChannel {
  PermissionChannel();

  static const _channel = MethodChannel('com.koru/permissions');

  Future<bool> checkAccessibilityService() async =>
      (await _channel.invokeMethod<bool>('checkAccessibilityService')) ?? false;

  Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod<void>('openAccessibilitySettings');

  Future<bool> checkUsageStatsPermission() async =>
      (await _channel.invokeMethod<bool>('checkUsageStatsPermission')) ?? false;

  Future<void> openUsageStatsSettings() =>
      _channel.invokeMethod<void>('openUsageStatsSettings');

  Future<bool> checkOverlayPermission() async =>
      (await _channel.invokeMethod<bool>('checkOverlayPermission')) ?? false;

  Future<void> openOverlaySettings() =>
      _channel.invokeMethod<void>('openOverlaySettings');

  Future<bool> checkBatteryOptimization() async =>
      (await _channel.invokeMethod<bool>('checkBatteryOptimization')) ?? false;

  Future<void> requestDisableBatteryOptimization() =>
      _channel.invokeMethod<void>('requestDisableBatteryOptimization');

  Future<bool> checkNotificationListener() async =>
      (await _channel.invokeMethod<bool>('checkNotificationListener')) ?? false;

  Future<void> openNotificationListenerSettings() =>
      _channel.invokeMethod<void>('openNotificationListenerSettings');

  Future<bool> isDefaultLauncher() async =>
      (await _channel.invokeMethod<bool>('isDefaultLauncher')) ?? false;

  Future<void> openDefaultLauncherSettings() =>
      _channel.invokeMethod<void>('openDefaultLauncherSettings');

  /// Abilita/disabilita l'activity-alias HOME di Koru.
  Future<bool> setLauncherModeEnabled(bool enabled) async =>
      (await _channel.invokeMethod<bool>('setLauncherModeEnabled', {
        'enabled': enabled,
      })) ??
      false;

  Future<bool> isLauncherModeEnabled() async =>
      (await _channel.invokeMethod<bool>('isLauncherModeEnabled')) ?? false;

  Future<KoruPermissionStatus> checkAllPermissions() async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('checkAllPermissions');
    return KoruPermissionStatus.fromMap(raw ?? const {});
  }
}
