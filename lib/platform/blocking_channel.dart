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

/// Limite giornaliero per un singolo package. `strict=true` implica hard
/// cap: l'overlay USAGE_LIMIT non offre "Open anyway". `strict=false`
/// abilita progressive friction (countdown crescente, durate decrescenti).
class AppLimitConfig {
  const AppLimitConfig({required this.minutes, required this.strict});

  final int minutes;
  final bool strict;

  Map<String, dynamic> toMap() => {'minutes': minutes, 'strict': strict};

  /// Tollera valori `int` legacy (formato di scambio precedente): in quel
  /// caso `strict` è assunto `true`. Ritorna `null` se `minutes <= 0`.
  static AppLimitConfig? fromAny(dynamic raw) {
    if (raw is num) {
      final m = raw.toInt();
      if (m <= 0) return null;
      return AppLimitConfig(minutes: m, strict: true);
    }
    if (raw is Map) {
      final m = (raw['minutes'] as num?)?.toInt() ?? 0;
      if (m <= 0) return null;
      final s = raw['strict'] as bool? ?? true;
      return AppLimitConfig(minutes: m, strict: s);
    }
    return null;
  }

  AppLimitConfig copyWith({int? minutes, bool? strict}) => AppLimitConfig(
        minutes: minutes ?? this.minutes,
        strict: strict ?? this.strict,
      );
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

/// Utilizzo foreground di un singolo giorno (mezzanotte locale →
/// mezzanotte locale): la lista delle app con i rispettivi ms in
/// foreground in quel giorno. Prodotto dal bucketing nativo
/// `getUsageStatsByDay`, che fa una sola passata di `queryEvents`.
class DailyUsage {
  DailyUsage({required this.dayStartMs, required this.apps});

  /// Mezzanotte locale del giorno, in ms epoch.
  final int dayStartMs;
  final List<AppUsageInfo> apps;

  /// Somma dei ms in foreground di tutte le app del giorno.
  int get totalMs => apps.fold<int>(0, (sum, a) => sum + a.totalTimeMs);

  factory DailyUsage.fromMap(Map<dynamic, dynamic> map) => DailyUsage(
        dayStartMs: (map['dayStartMs'] as num).toInt(),
        apps: ((map['apps'] as List<dynamic>?) ?? const <dynamic>[])
            .cast<Map<dynamic, dynamic>>()
            .map(
              (e) => AppUsageInfo(
                packageName: e['packageName'] as String,
                totalTimeMs: (e['totalTimeMs'] as num).toInt(),
                lastTimeUsed: 0,
              ),
            )
            .toList(growable: false),
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

  /// Variante leggera: solo i package names launchable, senza label e
  /// senza icon bytes. Usato dal lifecycle observer per fare un diff
  /// rapido ed evitare l'invalidazione di [installedAppsProvider] quando
  /// la lista non è cambiata (evita freeze visibile al resume).
  Future<List<String>> getInstalledPackageNames() async {
    final raw =
        await _channel.invokeListMethod<String>('getInstalledPackageNames');
    return raw ?? const [];
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

  /// Variante per-giorno di [getUsageStats]: ritorna un [DailyUsage] per
  /// ogni giorno con utilizzo nella finestra `[startMs, endMs]`, con le app
  /// del giorno e i loro ms in foreground. Usato dalla vista "settimana"
  /// delle statistiche per il drill-down sul singolo giorno.
  Future<List<DailyUsage>> getUsageStatsByDay({
    required int startMs,
    required int endMs,
  }) async {
    final raw = await _channel.invokeMethod<List<dynamic>>(
      'getUsageStatsByDay',
      {'startMs': startMs, 'endMs': endMs},
    );
    if (raw == null) return const [];
    return raw
        .cast<Map<dynamic, dynamic>>()
        .map(DailyUsage.fromMap)
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

  Future<bool> uninstallApp(String packageName) async =>
      (await _channel.invokeMethod<bool>('uninstallApp', {
        'packageName': packageName,
      })) ??
      false;

  Future<bool> openAppInfo(String packageName) async =>
      (await _channel.invokeMethod<bool>('openAppInfo', {
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

  Future<Map<String, AppLimitConfig>> getAppDailyLimits() async {
    final raw = await _channel
        .invokeMapMethod<String, dynamic>('getAppDailyLimits');
    if (raw == null) return const {};
    final out = <String, AppLimitConfig>{};
    raw.forEach((k, v) {
      final cfg = AppLimitConfig.fromAny(v);
      if (cfg != null) out[k] = cfg;
    });
    return out;
  }

  Future<bool> setAppDailyLimits(Map<String, AppLimitConfig> limits) async =>
      (await _channel.invokeMethod<bool>('setAppDailyLimits', {
        'limits': limits.map((k, v) => MapEntry(k, v.toMap())),
      })) ??
      false;

  Future<int> getBypassCountToday(String packageName) async =>
      (await _channel.invokeMethod<int>('getBypassCountToday', {
        'packageName': packageName,
      })) ??
      0;

  Future<void> resetBypassCount(String packageName) async {
    await _channel.invokeMethod<bool>('resetBypassCount', {
      'packageName': packageName,
    });
  }

  Future<int> getUsageTodayMs(String packageName) async =>
      (await _channel.invokeMethod<int>('getUsageTodayMs', {
        'packageName': packageName,
      })) ??
      0;

  Future<List<String>> getSilencedPackages() async {
    final raw = await _channel.invokeListMethod<String>('getSilencedPackages');
    return raw ?? const [];
  }

  Future<bool> setSilencedPackages(List<String> packages) async =>
      (await _channel.invokeMethod<bool>('setSilencedPackages', {
        'packages': packages,
      })) ??
      false;

  Future<bool> isNotificationAccessGranted() async =>
      (await _channel.invokeMethod<bool>('isNotificationAccessGranted')) ??
      false;

  Future<void> openNotificationAccessSettings() async {
    await _channel.invokeMethod<bool>('openNotificationAccessSettings');
  }

  Future<String?> getCurrentWifiSsid() async =>
      _channel.invokeMethod<String>('getCurrentWifiSsid');
}
