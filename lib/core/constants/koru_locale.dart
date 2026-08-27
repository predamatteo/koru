import 'package:flutter/widgets.dart';

/// Lingua scelta dall'utente in Impostazioni › Aspetto › Lingua.
///
/// `system` non è una lingua: è l'assenza di una scelta esplicita, e si traduce
/// in `locale: null` su `MaterialApp` (Flutter risolve sul locale di sistema) e
/// in una `LocaleList` vuota lato native (Android torna al default).
///
/// Il valore persistito è [storageValue], NON `index`: l'ordine dell'enum deve
/// poter cambiare (è anche l'ordine di visualizzazione nel picker) senza
/// riscrivere la preferenza già salvata in Hive.
enum KoruLocale {
  system('system', null),
  italian('it', Locale('it')),
  english('en', Locale('en'));

  const KoruLocale(this.storageValue, this.locale);

  /// Chiave persistita in Hive (`HiveKeys.localeCode`) e BCP-47 tag passato al
  /// native. Per [system] il tag è la stringa vuota lato native.
  final String storageValue;

  /// `null` per [system] — è esattamente ciò che `MaterialApp.locale` si
  /// aspetta per "segui il sistema".
  final Locale? locale;

  /// Tag BCP-47 per `LocaleManager.setApplicationLocales`. Stringa vuota =
  /// "nessun override", che è come Android esprime il ritorno al default.
  String get languageTag => this == system ? '' : storageValue;

  /// Parsing difensivo: un valore assente, vuoto o non più riconosciuto (una
  /// lingua rimossa da una versione futura) degrada a [system] invece di
  /// lanciare — la preferenza di lingua non può impedire l'avvio dell'app.
  static KoruLocale fromStorage(String? value) {
    if (value == null || value.isEmpty) return system;
    for (final l in KoruLocale.values) {
      if (l.storageValue == value) return l;
    }
    return system;
  }
}
