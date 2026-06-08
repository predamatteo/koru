import 'package:flutter/services.dart';

/// Notifica al native side che la configurazione profili in Drift è cambiata.
/// Il native fa broadcast ACTION_RELOAD_PROFILES al blocking engine.
class ProfileChannel {
  ProfileChannel();

  static const _channel = MethodChannel('com.koru/profiles');

  Future<void> notifyProfileChanged(int profileId) =>
      _channel.invokeMethod<void>('notifyProfileChanged', {'profileId': profileId});

  Future<void> notifyProfileToggled({required int profileId, required bool enabled}) =>
      _channel.invokeMethod<void>('notifyProfileToggled', {
        'profileId': profileId,
        'enabled': enabled,
      });

  Future<void> setProfilePaused(int profileId, {int? pausedUntilMs}) =>
      _channel.invokeMethod<void>('setProfilePaused', {
        'profileId': profileId,
        'pausedUntilMs': pausedUntilMs,
      });

  Future<void> syncAll() => _channel.invokeMethod<void>('syncAll');

  /// Propaga al native il font scelto dall'utente (KoruFont.id). L'overlay di
  /// blocco gira nel processo `:accessibility`, che non legge Hive: il native
  /// lo persiste in uno store cross-process e lo applica all'overlay.
  Future<void> setActiveFontId(int fontId) =>
      _channel.invokeMethod<void>('setActiveFontId', {'fontId': fontId});
}
