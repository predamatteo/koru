import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/hive_keys.dart';
import '../../core/constants/koru_locale.dart';
import '../../core/di/providers.dart';

/// Lingua dell'app, persistita in Hive e propagata ad Android.
///
/// Hive è l'unica fonte di verità. Il per-app language di Android (API 33+) è
/// uno *specchio*: serve perché overlay di blocco, notifiche del foreground
/// service e widget home sono nativi e risolvono le stringhe da `res/values*`,
/// che non sanno niente di Hive. Senza quella propagazione si finisce con la UI
/// Flutter in una lingua e l'overlay nell'altra.
///
/// Su API < 33 `LocaleManager` non esiste: la UI Flutter cambia lingua lo
/// stesso (è `MaterialApp.locale` a deciderlo), il lato native resta sul locale
/// di sistema. È una degradazione accettata e dichiarata, non un bug.
class LocalePreferenceNotifier extends Notifier<KoruLocale> {
  @override
  KoruLocale build() {
    final hive = ref.watch(hiveSettingsServiceProvider);
    return KoruLocale.fromStorage(
      hive.getString(HiveKeys.settingsBox, HiveKeys.localeCode),
    );
  }

  Future<void> set(KoruLocale locale) async {
    final hive = ref.read(hiveSettingsServiceProvider);
    await hive.put(HiveKeys.settingsBox, HiveKeys.localeCode, locale.storageValue);
    state = locale;
    unawaited(_pushToNative(locale));
  }

  /// Ri-asserisce sul native la lingua salvata in Hive.
  ///
  /// Serve perché il per-app locale di Android è uno stato di sistema che può
  /// divergere da Hive senza che l'app lo sappia: l'utente può cambiarlo da
  /// Impostazioni Android › App › Koru › Lingua, e un backup/restore ripristina
  /// Hive ma non le impostazioni di sistema. Chiamata una volta all'avvio.
  Future<void> syncToNative() => _pushToNative(state);

  /// Fire-and-forget: un canale morto (native non ancora pronto, o il caso
  /// normale su API < 33) non deve far fallire il cambio lingua lato UI, che è
  /// già stato persistito e applicato.
  ///
  /// `try`/`catch` e non `.catchError`: quest'ultimo intercetta solo una Future
  /// che fallisce, non un errore lanciato **prima** che la Future esista — e
  /// quello è esattamente il caso di un channel non registrato, dove la
  /// chiamata esplode in modo sincrono.
  Future<void> _pushToNative(KoruLocale locale) async {
    try {
      await ref
          .read(platformChannelServiceProvider)
          .profile
          .setAppLocale(locale.languageTag);
    } catch (_) {
      // Volutamente ingoiato: vedi sopra.
    }
  }
}

final localePreferenceProvider =
    NotifierProvider<LocalePreferenceNotifier, KoruLocale>(
  LocalePreferenceNotifier.new,
);

/// Provider side-effecting osservato da `KoruApp`: riallinea una volta il
/// per-app locale di Android alla preferenza salvata in Hive.
///
/// Non espone stato — esiste solo per la sua costruzione. È separato dal
/// notifier perché `build()` di un `Notifier` deve restare puro: fare la
/// chiamata al channel lì dentro la rifarebbe a ogni invalidazione di
/// `hiveSettingsServiceProvider`.
final localeNativeSyncProvider = Provider<void>((ref) {
  unawaited(ref.read(localePreferenceProvider.notifier).syncToNative());
});
