import 'package:flutter/services.dart';

/// Bit flags per le opzioni di Strict Mode (devono matchare StrictModeEnforcer lato native).
class StrictModeOption {
  const StrictModeOption._();

  static const int blockEditing = 1;
  static const int blockSettings = 2;
  static const int blockUninstalling = 4;
  static const int blockRecentApps = 8;
  static const int blockSplitScreen = 16;

  /// Mask con tutte le restrizioni MVP attive.
  static const int allMvp =
      blockSettings | blockUninstalling | blockRecentApps;
}

/// Outcome di una validazione di backdoor code lato Kotlin. Tutti i path
/// di errore (rate limit, replay, invalid) sono modellati come [BackdoorOutcome]
/// invece di un bool, così l'UI può differenziare il messaging.
sealed class BackdoorOutcome {
  const BackdoorOutcome();
}

class BackdoorValid extends BackdoorOutcome {
  const BackdoorValid();
}

class BackdoorInvalid extends BackdoorOutcome {
  const BackdoorInvalid();
}

class BackdoorReplay extends BackdoorOutcome {
  const BackdoorReplay();
}

class BackdoorLocked extends BackdoorOutcome {
  const BackdoorLocked(this.remainingMs);
  final int remainingMs;
}

/// Strict Mode method channel.
///
/// Contratto Kotlin (`com.koru/strict_mode`):
/// - `getStrictModeOptions` → `int` bitmask della mask corrente.
/// - `setStrictModeOptions {mask: int}` → void.
/// - `enableDeviceAdmin`/`disableDeviceAdmin` → bool.
///   - `disableDeviceAdmin` può ritornare `PlatformException(STRICT_ACTIVE)`
///     se strict mode è attivo (l'utente deve prima passare backdoor code).
/// - `isDeviceAdminActive` → bool.
/// - `generateBackdoorCode` → string (code corrente, già rotated weekly).
/// - `validateBackdoorCode {code: string}` → bool, oppure
///   `PlatformException(LOCKED_OUT|REPLAY)`.
/// - `performEmergencyUnblock {code: string}` → bool (true = mask azzerata).
///   Può ritornare `PlatformException(INVALID_CODE|LOCKED_OUT|REPLAY)`.
/// - `getRemainingAttempts` → int (tentativi rimasti prima del prossimo lockout).
/// - `getLockoutRemainingMs` → int (0 se non in lockout).
/// - `isStrictModeActive` → bool.
class StrictModeChannel {
  StrictModeChannel();

  static const _channel = MethodChannel('com.koru/strict_mode');

  Future<bool> enableDeviceAdmin() async =>
      (await _channel.invokeMethod<bool>('enableDeviceAdmin')) ?? false;

  /// Disabilita Device Admin. Lancia [PlatformException] con code
  /// `STRICT_ACTIVE` se strict mode è ancora attivo — l'UI deve guidare
  /// l'utente a usare prima il backdoor code.
  Future<bool> disableDeviceAdmin() async =>
      (await _channel.invokeMethod<bool>('disableDeviceAdmin')) ?? false;

  Future<bool> isDeviceAdminActive() async =>
      (await _channel.invokeMethod<bool>('isDeviceAdminActive')) ?? false;

  Future<void> setStrictModeOptions(int mask) =>
      _channel.invokeMethod<void>('setStrictModeOptions', {'mask': mask});

  Future<int> getStrictModeOptions() async =>
      (await _channel.invokeMethod<int>('getStrictModeOptions')) ?? 0;

  Future<String> generateBackdoorCode() async =>
      (await _channel.invokeMethod<String>('generateBackdoorCode')) ?? '';

  /// Validazione del code. Lato Kotlin gestisce rate limit + replay; questo
  /// metodo wrappa l'outcome in [BackdoorOutcome] così la UI non deve
  /// destrutturare PlatformException.
  Future<BackdoorOutcome> validateBackdoorCode(String code) async {
    try {
      final ok =
          (await _channel.invokeMethod<bool>('validateBackdoorCode', {
        'code': code,
      })) ??
              false;
      return ok ? const BackdoorValid() : const BackdoorInvalid();
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'LOCKED_OUT':
          final ms = (e.details is int) ? e.details as int : 0;
          return BackdoorLocked(ms);
        case 'REPLAY':
          return const BackdoorReplay();
        default:
          return const BackdoorInvalid();
      }
    }
  }

  /// Emergency unblock atomico: validate(code) → markUsed → setMask(0)
  /// → removeDeviceAdmin. Il [code] è obbligatorio (prima era senza
  /// parametri: chiunque potesse invocare il channel poteva azzerare la
  /// mask senza autenticazione — fix S4).
  ///
  /// Ritorna [BackdoorValid] solo se l'unblock è andato a buon fine.
  Future<BackdoorOutcome> performEmergencyUnblock(String code) async {
    try {
      final ok = (await _channel.invokeMethod<bool>('performEmergencyUnblock', {
            'code': code,
          })) ??
          false;
      return ok ? const BackdoorValid() : const BackdoorInvalid();
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'LOCKED_OUT':
          final ms = (e.details is int) ? e.details as int : 0;
          return BackdoorLocked(ms);
        case 'REPLAY':
          return const BackdoorReplay();
        case 'INVALID_CODE':
          return const BackdoorInvalid();
        default:
          return const BackdoorInvalid();
      }
    }
  }

  /// Tentativi rimasti prima del prossimo step di lockout. UI lo mostra
  /// come "X tentativi rimanenti" sotto al campo input.
  Future<int> getRemainingAttempts() async =>
      (await _channel.invokeMethod<int>('getRemainingAttempts')) ?? 0;

  /// Ms rimanenti se siamo dentro un lockout, altrimenti 0.
  Future<int> getLockoutRemainingMs() async =>
      (await _channel.invokeMethod<int>('getLockoutRemainingMs')) ?? 0;

  Future<bool> isStrictModeActive() async =>
      (await _channel.invokeMethod<bool>('isStrictModeActive')) ?? false;
}
