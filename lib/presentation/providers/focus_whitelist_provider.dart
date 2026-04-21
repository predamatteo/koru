import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/default_whitelist.dart';
import '../../core/constants/hive_keys.dart';
import '../../core/di/providers.dart';

enum FocusMode { quickBlock, pomodoro }

class _FocusWhitelistNotifier extends FamilyNotifier<Set<String>, FocusMode> {
  String _keyFor(FocusMode m) => switch (m) {
        FocusMode.quickBlock => 'quick_block_whitelist',
        FocusMode.pomodoro => 'pomodoro_whitelist',
      };

  @override
  Set<String> build(FocusMode arg) {
    final hive = ref.watch(hiveSettingsServiceProvider);
    final saved = hive.getStringList(HiveKeys.uiStateBox, _keyFor(arg));
    if (saved.isEmpty) return kDefaultFocusWhitelist;
    // Merge: se l'utente ha già una whitelist salvata, uniamo i nuovi package
    // di default (es. clock app OEM aggiunte in release successive) per non
    // lasciare sveglie/emergenze bloccate dopo un update.
    return {...saved, ...kDefaultFocusWhitelist};
  }

  Future<void> add(String packageName) async {
    final next = {...state, packageName};
    await _save(next);
    state = next;
  }

  Future<void> remove(String packageName) async {
    final next = {...state}..remove(packageName);
    await _save(next);
    state = next;
  }

  Future<void> toggle(String packageName) async {
    if (state.contains(packageName)) {
      await remove(packageName);
    } else {
      await add(packageName);
    }
  }

  Future<void> resetToDefaults() async {
    await _save(kDefaultFocusWhitelist);
    state = kDefaultFocusWhitelist;
  }

  Future<void> _save(Set<String> value) async {
    final hive = ref.read(hiveSettingsServiceProvider);
    await hive.setStringList(
      HiveKeys.uiStateBox,
      _keyFor(arg),
      value.toList(growable: false),
    );
  }
}

final focusWhitelistProvider =
    NotifierProvider.family<_FocusWhitelistNotifier, Set<String>, FocusMode>(
  _FocusWhitelistNotifier.new,
);
