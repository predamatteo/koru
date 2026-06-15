import 'dart:async';

import '../../data/local/hive_settings_service.dart';
import '../constants/hive_keys.dart';
import 'black_box.dart';

/// Funnel milestone LOCALI, mai inviati off-device.
///
/// Servono a interpretare post-lancio il funnel
/// install → accessibility-granted → … → purchase SENZA telemetria: le coorti
/// aggregate (install, retention, acquisti) arrivano da Play Console / Play
/// Billing; questi timestamp locali sono solo per QA on-device (via `adb` sul
/// BlackBox) e per debug. Scrittura WRITE-ONCE: il primo evento vince, i
/// successivi sono no-op. Vedi FUNNEL.md per il modello completo.
///
/// Nota: alcuni milestone NON vivono qui perché già nel DB relazionale (Drift):
/// `firstBlockTriggeredAt` = MIN(block_sessions.timestamp). `firstProfile` non
/// è ancora tracciato (la tabella Profiles non ha createdAt) — vedi FUNNEL.md.
class FunnelMilestones {
  const FunnelMilestones._();

  static void _markOnce(HiveSettingsService hive, String key) {
    // Best-effort: la telemetria locale del funnel non deve MAI propagare un
    // errore ai chiamanti (es. il tick di accessibilityHealthProvider, dove
    // un throw farebbe emettere `false` allo stream di health).
    try {
      final existing = hive.get<int>(HiveKeys.settingsBox, key);
      if (existing != null) return;
      unawaited(
        hive.put(
          HiveKeys.settingsBox,
          key,
          DateTime.now().millisecondsSinceEpoch,
        ),
      );
      BlackBox.log('FUNNEL', '$key set');
    } catch (_) {
      // milestone perso: irrilevante, è solo QA locale.
    }
  }

  /// Primo avvio dell'app (chiamato dal bootstrap in `main()`).
  static void markFirstInstall(HiveSettingsService hive) =>
      _markOnce(hive, HiveKeys.firstInstallTimestamp);

  /// Prima volta in cui l'AccessibilityService risulta concesso.
  static void markAccessibilityGranted(HiveSettingsService hive) =>
      _markOnce(hive, HiveKeys.accessibilityGrantedAt);

  /// Snapshot dei milestone locali (ms epoch, null se non ancora raggiunti).
  static Map<String, int?> snapshot(HiveSettingsService hive) => {
        'firstInstallAt':
            hive.get<int>(HiveKeys.settingsBox, HiveKeys.firstInstallTimestamp),
        'accessibilityGrantedAt': hive.get<int>(
          HiveKeys.settingsBox,
          HiveKeys.accessibilityGrantedAt,
        ),
      };

  /// Dump dei milestone nel BlackBox (recuperabile via `adb pull`), così il
  /// dev può ispezionare il funnel senza alcun backend.
  static void dumpToBlackBox(HiveSettingsService hive) =>
      BlackBox.log('FUNNEL', 'snapshot ${snapshot(hive)}');
}
