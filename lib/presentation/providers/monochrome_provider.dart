import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/hive_keys.dart';
import '../../core/di/providers.dart';

/// ORFANO al momento: l'impostazione è stata rimossa dalle Impostazioni e il
/// filtro in `app.dart` è commentato, quindi nessuna UI referenzia più questo
/// provider. Resta compilabile (e testato) di proposito, così ripristinare la
/// feature è solo un de-commento nei due call-site; il valore in Hive
/// (`MONOCHROME_ENABLED`) non viene cancellato.
///
/// Toggle globale del filtro monochrome (grayscale) applicato all'intera
/// UI di Koru. Abilitarlo riduce l'appeal visivo — soprattutto in
/// launcher mode rende i colori vibranti delle icone app molto meno
/// "magnetici".
///
/// Nota: copre solo la UI di Koru. Il grayscale system-wide richiederebbe
/// WRITE_SECURE_SETTINGS (non concedibile senza `adb shell pm grant`),
/// quindi evitiamo di provare la strada a livello OS.
class MonochromeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final hive = ref.watch(hiveSettingsServiceProvider);
    return hive.getBool(
      HiveKeys.settingsBox,
      HiveKeys.monochromeEnabled,
      defaultValue: false,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    await ref.read(hiveSettingsServiceProvider).put(
          HiveKeys.settingsBox,
          HiveKeys.monochromeEnabled,
          enabled,
        );
    state = enabled;
  }

  Future<void> toggle() => setEnabled(!state);
}

final monochromeProvider = NotifierProvider<MonochromeNotifier, bool>(
  MonochromeNotifier.new,
);
