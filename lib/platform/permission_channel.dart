import 'package:flutter/services.dart';

class KoruPermissionStatus {
  const KoruPermissionStatus({
    required this.accessibility,
    required this.usageStats,
    required this.overlay,
    required this.batteryOptimizationIgnored,
    required this.notifications,
    required this.notificationListener,
    required this.defaultLauncher,
  });

  final bool accessibility;
  final bool usageStats;
  final bool overlay;
  final bool batteryOptimizationIgnored;

  /// POST_NOTIFICATIONS (Android 13+) *oppure* notifiche dell'app spente a
  /// mano: entrambi i casi impediscono al foreground service e agli alert
  /// dello strict mode di comparire.
  final bool notifications;

  /// Accesso alle notifiche ALTRUI (NotificationListenerService), usato per
  /// filtrare quelle delle app bloccate. Nulla a che vedere con [notifications].
  final bool notificationListener;
  final bool defaultLauncher;

  bool get allMandatoryGranted => accessibility && usageStats && overlay;

  factory KoruPermissionStatus.fromMap(Map<dynamic, dynamic> map) =>
      KoruPermissionStatus(
        accessibility: map['accessibility'] as bool? ?? false,
        usageStats: map['usageStats'] as bool? ?? false,
        overlay: map['overlay'] as bool? ?? false,
        batteryOptimizationIgnored: map['battery'] as bool? ?? false,
        notifications: map['notifications'] as bool? ?? false,
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

  /// `true` se Koru può postare notifiche (POST_NOTIFICATIONS concesso su
  /// Android 13+ **e** notifiche dell'app non spente a mano).
  Future<bool> checkNotificationPermission() async =>
      (await _channel.invokeMethod<bool>('checkNotificationPermission')) ??
      false;

  /// Mostra il dialog runtime di POST_NOTIFICATIONS (Android 13+) e risolve
  /// con l'esito. Quando il dialog non può comparire — API < 33, oppure
  /// permesso già negato in modo permanente — il lato nativo apre direttamente
  /// la pagina Notifiche di Koru nelle impostazioni di sistema e ritorna
  /// `false`: in ogni caso l'utente finisce dove può concedere il permesso.
  Future<bool> requestNotificationPermission() async =>
      (await _channel.invokeMethod<bool>('requestNotificationPermission')) ??
      false;

  /// Apre la pagina Notifiche di Koru nelle impostazioni di sistema.
  Future<void> openAppNotificationSettings() =>
      _channel.invokeMethod<void>('openAppNotificationSettings');

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
