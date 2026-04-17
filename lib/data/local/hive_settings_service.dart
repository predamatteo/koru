import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../core/constants/hive_keys.dart';

/// Facade che espone le 6 box di Koru e una API tipizzata per settings/KV.
///
/// Pattern ereditato da ascent (hive_settings_service.dart) ma adattato a hive_ce
/// e alle box Koru.
class HiveSettingsService {
  late final Box _settingsBox;
  late final Box _onboardingBox;
  late final Box _uiStateBox;
  late final Box _cacheBox;
  late final Box _hiddenAppsBox;
  late final Box _quickTogglesBox;

  Future<void> init() async {
    _settingsBox = await Hive.openBox(HiveKeys.settingsBox);
    _onboardingBox = await Hive.openBox(HiveKeys.onboardingBox);
    _uiStateBox = await Hive.openBox(HiveKeys.uiStateBox);
    _cacheBox = await Hive.openBox(HiveKeys.cacheBox);
    _hiddenAppsBox = await Hive.openBox(HiveKeys.hiddenAppsBox);
    _quickTogglesBox = await Hive.openBox(HiveKeys.quickTogglesBox);
  }

  // Generic typed accessors ---------------------------------------------------
  T? get<T>(String boxName, String key) => _boxFor(boxName).get(key) as T?;

  Future<void> put(String boxName, String key, dynamic value) =>
      _boxFor(boxName).put(key, value);

  Future<void> delete(String boxName, String key) =>
      _boxFor(boxName).delete(key);

  bool getBool(String boxName, String key, {bool defaultValue = false}) =>
      _boxFor(boxName).get(key, defaultValue: defaultValue) as bool;

  int getInt(String boxName, String key, {int defaultValue = 0}) =>
      _boxFor(boxName).get(key, defaultValue: defaultValue) as int;

  String getString(String boxName, String key, {String defaultValue = ''}) =>
      _boxFor(boxName).get(key, defaultValue: defaultValue) as String;

  List<String> getStringList(String boxName, String key) {
    final value = _boxFor(boxName).get(key);
    if (value == null) return const [];
    if (value is List) return value.cast<String>();
    return const [];
  }

  Future<void> setStringList(
    String boxName,
    String key,
    List<String> value,
  ) =>
      _boxFor(boxName).put(key, value);

  /// Stream che emette ogni volta che cambia un valore in una box.
  Stream<BoxEvent> watch(String boxName, {String? key}) =>
      _boxFor(boxName).watch(key: key);

  Box _boxFor(String name) {
    switch (name) {
      case HiveKeys.settingsBox:
        return _settingsBox;
      case HiveKeys.onboardingBox:
        return _onboardingBox;
      case HiveKeys.uiStateBox:
        return _uiStateBox;
      case HiveKeys.cacheBox:
        return _cacheBox;
      case HiveKeys.hiddenAppsBox:
        return _hiddenAppsBox;
      case HiveKeys.quickTogglesBox:
        return _quickTogglesBox;
      default:
        throw ArgumentError('Unknown Hive box: $name');
    }
  }
}
