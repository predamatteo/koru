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
  const BackdoorValid(this.unblockToken);

  /// SEC-01: token monouso emesso dal native dopo la validazione riuscita.
  /// Va ripassato a [StrictModeChannel.setStrictModeOptions] per autorizzare
  /// lo spegnimento di bit attivi (downgrade della mask). Può essere `null`
  /// se il native non lo ha emesso (es. versione vecchia) — in quel caso il
  /// downgrade verrà rifiutato lato native, fail-secure.
  final String? unblockToken;
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
/// - `generateBackdoorCode` → string (code corrente, già rotated weekly),
///   oppure `null` se il Keystore non è disponibile (SEC-10, fail-secure).
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

  /// Imposta la mask delle opzioni strict mode.
  ///
  /// SEC-01: ALZARE la mask (aggiungere restrizioni) è libero. SPEGNERE un bit
  /// attivo (downgrade) richiede [unblockToken] — il token monouso restituito
  /// da [validateBackdoorCode] dopo una validazione riuscita del backdoor code.
  /// Senza token valido il native rifiuta il downgrade con
  /// `PlatformException(UNAUTHORIZED)` e la mask resta invariata.
  Future<void> setStrictModeOptions(int mask, {String? unblockToken}) =>
      _channel.invokeMethod<void>('setStrictModeOptions', <String, Object?>{
        'mask': mask,
        // Includi la chiave solo se il token è non-null (downgrade); con token
        // null l'entry è omessa e il native tratta il cambio come "raising".
        // ignore: use_null_aware_elements
        if (unblockToken != null) 'unblockToken': unblockToken,
      });

  Future<int> getStrictModeOptions() async =>
      (await _channel.invokeMethod<int>('getStrictModeOptions')) ?? 0;

  /// Codice settimanale corrente, oppure `null` se il native non può emetterne
  /// uno (SEC-10: Keystore non disponibile → fail-secure, nessun codice
  /// deterministico indovinabile). L'UI mostra il `null` come "temporaneamente
  /// non disponibile, riprova" invece di un codice fittizio.
  Future<String?> generateBackdoorCode() async =>
      _channel.invokeMethod<String>('generateBackdoorCode');

  /// Validazione del code. Lato Kotlin gestisce rate limit + replay; questo
  /// metodo wrappa l'outcome in [BackdoorOutcome] così la UI non deve
  /// destrutturare PlatformException.
  ///
  /// SEC-01: su successo il native ritorna un token monouso (string) invece di
  /// `true`; lo propaghiamo in [BackdoorValid.unblockToken] perché il chiamante
  /// lo passi a [setStrictModeOptions] per autorizzare il downgrade della mask.
  Future<BackdoorOutcome> validateBackdoorCode(String code) async {
    try {
      final token = await _channel.invokeMethod<String>('validateBackdoorCode', {
        'code': code,
      });
      return (token != null && token.isNotEmpty)
          ? BackdoorValid(token)
          : const BackdoorInvalid();
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
      // performEmergencyUnblock azzera la mask lato native (path già
      // autenticato dal code) → nessun token da propagare.
      return ok ? const BackdoorValid(null) : const BackdoorInvalid();
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
