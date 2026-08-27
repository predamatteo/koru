import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/koru_locale.dart';
import 'package:koru/l10n/generated/app_localizations.dart';

/// Guardrail delle traduzioni, nello spirito di `db_schema_contract_test`:
/// tiene insieme quattro elenchi che devono dire la stessa cosa e che nessun
/// compilatore confronta fra loro.
///
/// - `app_en.arb` è il template: ogni sua chiave deve esistere in `app_it.arb`;
/// - i **placeholder** di ogni messaggio devono coincidere fra le due lingue —
///   un `{count}` dimenticato nella traduzione non è un errore di compilazione,
///   è una frase che sul dispositivo esce monca;
/// - `AppLocalizations.supportedLocales`, `KoruLocale` e
///   `res/xml/locales_config.xml` devono elencare le stesse lingue, altrimenti
///   il selettore in-app offre una lingua che il sistema scarta in silenzio.
void main() {
  final arbDir = Directory('lib/l10n');

  Map<String, dynamic> readArb(String name) =>
      jsonDecode(File('${arbDir.path}/$name').readAsStringSync())
          as Map<String, dynamic>;

  /// Le chiavi di messaggio, senza i metadati `@chiave` e `@@locale`.
  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  /// I placeholder **dichiarati** in `@chiave.placeholders`.
  ///
  /// Si legge la dichiarazione e non il testo del messaggio: dentro un plurale
  /// ICU (`{count, plural, one{reel} other{reels}}`) le graffe annidate sono
  /// rami, non segnaposto, e cercarli con una regex conterebbe `reel` come se
  /// lo fosse.
  Set<String> declaredPlaceholders(Map<String, dynamic> arb, String key) {
    final meta = arb['@$key'];
    if (meta is! Map) return const {};
    final ph = meta['placeholders'];
    if (ph is! Map) return const {};
    return ph.keys.cast<String>().toSet();
  }

  /// Se [message] usa davvero [name], come `{name}` o come testa di un
  /// costrutto ICU `{name, plural…}`.
  bool messageUses(String message, String name) =>
      message.contains('{$name}') || message.contains('{$name,');

  late Map<String, dynamic> en;
  late Map<String, dynamic> it;

  setUpAll(() {
    en = readArb('app_en.arb');
    it = readArb('app_it.arb');
  });

  group('ARB parity', () {
    test('every English key is translated in Italian', () {
      final missing = messageKeys(en).difference(messageKeys(it));
      expect(
        missing,
        isEmpty,
        reason: 'Chiavi presenti in app_en.arb ma non in app_it.arb: $missing',
      );
    });

    test('Italian has no key the template does not define', () {
      // Una chiave solo italiana non viene mai generata: è codice morto che
      // sembra una traduzione fatta.
      final extra = messageKeys(it).difference(messageKeys(en));
      expect(
        extra,
        isEmpty,
        reason: 'Chiavi in app_it.arb che non esistono in app_en.arb: $extra',
      );
    });

    test('both locales declare the same placeholders', () {
      final mismatches = <String>[];
      for (final key in messageKeys(en)) {
        final a = declaredPlaceholders(en, key);
        final b = declaredPlaceholders(it, key);
        if (a.length != b.length || !a.containsAll(b)) {
          mismatches.add('$key: en=$a it=$b');
        }
      }
      expect(
        mismatches,
        isEmpty,
        reason: 'Placeholder dichiarati in modo diverso fra le lingue:\n'
            '${mismatches.join('\n')}',
      );
    });

    test('every declared placeholder is actually used in both messages', () {
      // È il caso che rompe davvero sul dispositivo: la traduzione compila lo
      // stesso, ma la frase esce senza il numero o senza il nome dell'app.
      final unused = <String>[];
      for (final key in messageKeys(en)) {
        for (final name in declaredPlaceholders(en, key)) {
          final enMsg = en[key];
          final itMsg = it[key];
          if (enMsg is String && !messageUses(enMsg, name)) {
            unused.add('en/$key: {$name} dichiarato ma non usato');
          }
          if (itMsg is String && !messageUses(itMsg, name)) {
            unused.add('it/$key: {$name} dichiarato ma non usato');
          }
        }
      }
      expect(unused, isEmpty, reason: unused.join('\n'));
    });

    test('no message is left empty', () {
      final empty = [
        for (final key in messageKeys(en))
          if (en[key] is String && (en[key] as String).trim().isEmpty) 'en/$key',
        for (final key in messageKeys(it))
          if (it[key] is String && (it[key] as String).trim().isEmpty) 'it/$key',
      ];
      expect(empty, isEmpty, reason: 'Messaggi vuoti: $empty');
    });
  });

  group('supported locales agree everywhere', () {
    test('KoruLocale covers every generated locale', () {
      final generated =
          AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
      final offered = KoruLocale.values
          .where((l) => l != KoruLocale.system)
          .map((l) => l.storageValue)
          .toSet();
      expect(
        offered,
        generated,
        reason: 'Il selettore in-app e AppLocalizations non offrono le stesse '
            'lingue: KoruLocale=$offered, generate=$generated',
      );
    });

    test('android locales_config.xml lists the same locales', () {
      final xml = File('android/app/src/main/res/xml/locales_config.xml')
          .readAsStringSync();
      final declared = RegExp(r'android:name="([^"]+)"')
          .allMatches(xml)
          .map((m) => m.group(1)!)
          .toSet();
      final generated =
          AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
      expect(
        declared,
        generated,
        reason: 'locales_config.xml e AppLocalizations divergono: '
            'xml=$declared, generate=$generated. Un tag non dichiarato viene '
            'scartato in silenzio da LocaleManager.',
      );
    });

    test('every supported locale actually resolves', () {
      for (final locale in AppLocalizations.supportedLocales) {
        expect(
          () => lookupAppLocalizations(locale),
          returnsNormally,
          reason: 'lookupAppLocalizations fallisce su $locale',
        );
      }
    });
  });

  group('KoruLocale', () {
    test('storage round-trips for every value', () {
      for (final l in KoruLocale.values) {
        expect(KoruLocale.fromStorage(l.storageValue), l);
      }
    });

    test('unknown, empty and null storage values degrade to system', () {
      // Una lingua rimossa in futuro non deve impedire l'avvio dell'app.
      expect(KoruLocale.fromStorage(null), KoruLocale.system);
      expect(KoruLocale.fromStorage(''), KoruLocale.system);
      expect(KoruLocale.fromStorage('klingon'), KoruLocale.system);
    });

    test('system means "no override" on both sides', () {
      // `null` è ciò che MaterialApp.locale vuole per "segui il sistema";
      // la stringa vuota è come Android esprime la LocaleList vuota.
      expect(KoruLocale.system.locale, isNull);
      expect(KoruLocale.system.languageTag, isEmpty);
    });

    test('a real language carries both a Locale and a BCP-47 tag', () {
      expect(KoruLocale.italian.locale, const Locale('it'));
      expect(KoruLocale.italian.languageTag, 'it');
      expect(KoruLocale.english.locale, const Locale('en'));
      expect(KoruLocale.english.languageTag, 'en');
    });
  });
}
