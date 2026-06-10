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

  /// Attiva/disattiva l'override delle gesture di sistema sul launcher (so the
  /// edge swipes aren't eaten by the system back/home gesture navigation).
  /// Da chiamare SOLO mentre la LauncherHomeScreen è montata. Android limita
  /// l'esclusione del back a 200dp/bordo e non consente di escludere la home
  /// gesture dal basso: vedi nota nel channel nativo. No-op < API 29.
  Future<void> setLauncherGestureExclusion(bool enabled) =>
      _channel.invokeMethod<void>('setLauncherGestureExclusion', {
        'enabled': enabled,
      });

  /// Attiva/disattiva il blocco della gesture recents (swipe-up-and-hold)
  /// scopato al launcher: il LauncherRecentsGate nativo richiude la schermata
  /// recents appena appare se l'utente veniva dal launcher Koru. Cavalca lo
  /// stesso lifecycle RouteAware di [setLauncherGestureExclusion] — da
  /// chiamare SOLO da LauncherHomeScreen._setLauncherActive.
  Future<void> setLauncherRecentsShield(bool enabled) =>
      _channel.invokeMethod<void>('setLauncherRecentsShield', {
        'enabled': enabled,
      });

  Future<KoruPermissionStatus> checkAllPermissions() async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('checkAllPermissions');
    return KoruPermissionStatus.fromMap(raw ?? const {});
  }
}
