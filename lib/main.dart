import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:koru/app.dart';
import 'package:koru/core/constants/hive_keys.dart';
import 'package:koru/core/di/providers.dart';
import 'package:koru/core/diagnostics/black_box.dart';
import 'package:koru/core/diagnostics/perf_observer.dart';
import 'package:koru/data/database/app_database.dart';
import 'package:koru/data/local/hive_settings_service.dart';
import 'package:koru/platform/profile_channel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Scatola nera: prima riga Dart della sessione. Se il channel nativo non e'
  // ancora pronto a questo istante e' un no-op silenzioso (il marker di cold
  // start autoritativo e' comunque `PROC Application.onCreate` lato nativo).
  BlackBox.log('DART', 'main() start (Flutter engine avviato)');

  // Timing del lavoro che BLOCCA il primo frame (await prima di runApp): se
  // questi secondi crescono al cold start, ritardano la comparsa del launcher.
  final swBoot = Stopwatch()..start();
  await Hive.initFlutter();
  BlackBox.log('DART', 'Hive.initFlutter fine (${swBoot.elapsedMilliseconds}ms)');
  final hiveSettings = HiveSettingsService();
  await hiveSettings.init();
  BlackBox.log(
    'DART',
    'hiveSettings.init fine (${swBoot.elapsedMilliseconds}ms totali pre-runApp)',
  );

  final database = AppDatabase();

  runApp(
    ProviderScope(
      // Diagnostica Fase 3 solo in debug (zero overhead in profile/release).
      observers: kDebugMode ? const [PerfObserver()] : const [],
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        hiveSettingsServiceProvider.overrideWithValue(hiveSettings),
      ],
      child: const KoruApp(),
    ),
  );

  // Allinea il font dell'overlay di blocco nativo (processo :accessibility, che
  // non legge Hive) alla preferenza salvata. Post-first-frame: garantisce che i
  // MethodChannel nativi siano registrati. Fire-and-forget; un fallimento viene
  // recuperato al prossimo cambio font o al prossimo avvio. Copre la migrazione
  // di chi aveva gia' un font custom prima di questa feature.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final fontId =
        hiveSettings.getInt(HiveKeys.uiStateBox, HiveKeys.activeFontId);
    unawaited(ProfileChannel().setActiveFontId(fontId).catchError((_) {}));
  });
}
