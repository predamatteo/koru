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

class StrictModeChannel {
  StrictModeChannel();

  static const _channel = MethodChannel('com.koru/strict_mode');

  Future<bool> enableDeviceAdmin() async =>
      (await _channel.invokeMethod<bool>('enableDeviceAdmin')) ?? false;

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

  Future<bool> validateBackdoorCode(String code) async =>
      (await _channel.invokeMethod<bool>('validateBackdoorCode', {'code': code})) ??
      false;

  Future<bool> performEmergencyUnblock() async =>
      (await _channel.invokeMethod<bool>('performEmergencyUnblock')) ?? false;

  Future<bool> isStrictModeActive() async =>
      (await _channel.invokeMethod<bool>('isStrictModeActive')) ?? false;
}
