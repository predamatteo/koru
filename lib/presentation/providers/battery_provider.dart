import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Snapshot dello stato batteria emesso dal native via sticky broadcast
/// `ACTION_BATTERY_CHANGED`. Aggiornato push-based: nessun polling.
class BatteryState {
  const BatteryState({required this.level, required this.charging});

  /// 0-100; -1 quando il dato non è ancora disponibile / unparseable.
  final int level;

  /// True se in carica (USB/AC/wireless) o batteria piena.
  final bool charging;
}

const _batteryChannel = EventChannel('com.koru/battery');

/// Stream di stato batteria via EventChannel `com.koru/battery`.
///
/// Sostituisce i precedenti due `StreamProvider` che facevano polling
/// (`getBatteryLevel` ogni 30s + `isCharging` ogni 10s). Il polling
/// drenava batteria anche in background — soprattutto se Koru è il
/// launcher e quindi è "il foreground" per il sistema appena l'utente
/// torna alla home.
///
/// Il broadcast nativo è "free": Android lo emette quando il livello
/// cambia davvero. La sticky broadcast garantisce un valore immediato
/// al subscribe (no flash di "—%" iniziale).
final batteryStateProvider = StreamProvider<BatteryState>((ref) {
  return _batteryChannel.receiveBroadcastStream().map((dynamic event) {
    if (event is Map) {
      final level = (event['level'] as num?)?.toInt() ?? -1;
      final charging = event['charging'] as bool? ?? false;
      return BatteryState(level: level, charging: charging);
    }
    return const BatteryState(level: -1, charging: false);
  });
});

/// Backward-compat: il livello batteria (0-100) come `int?`. UI esistente
/// che usava `batteryLevelProvider` continua a funzionare senza modifiche.
final batteryLevelProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(batteryStateProvider).whenData((s) => s.level);
});

/// Backward-compat: stato di carica come `bool`. UI esistente che usava
/// `isChargingProvider` continua a funzionare senza modifiche.
final isChargingProvider = Provider<AsyncValue<bool>>((ref) {
  return ref.watch(batteryStateProvider).whenData((s) => s.charging);
});
