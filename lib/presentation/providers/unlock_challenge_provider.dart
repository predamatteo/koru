import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/hive_keys.dart';
import '../../core/di/providers.dart';
import '../../domain/entities/unlock_challenge.dart';

/// Livello di attrito richiesto per **disattivare** una protezione.
///
/// Impostazione globale (non per-profilo): il punto della feature è che nel
/// momento dell'impulso non ci sia un profilo "facile" da spegnere. Vive su
/// Hive perché è un flag di UI-state, non un dato relazionale.
class UnlockChallengeNotifier extends Notifier<UnlockChallengeLevel> {
  @override
  UnlockChallengeLevel build() {
    final hive = ref.watch(hiveSettingsServiceProvider);
    return UnlockChallengeLevel.fromStorage(
      hive.get<String>(HiveKeys.settingsBox, HiveKeys.unlockChallengeLevel),
    );
  }

  Future<void> setLevel(UnlockChallengeLevel level) async {
    await ref
        .read(hiveSettingsServiceProvider)
        .put(
          HiveKeys.settingsBox,
          HiveKeys.unlockChallengeLevel,
          level.storageValue,
        );
    state = level;
  }
}

final unlockChallengeLevelProvider =
    NotifierProvider<UnlockChallengeNotifier, UnlockChallengeLevel>(
      UnlockChallengeNotifier.new,
    );
