import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:koru/app.dart';
import 'package:koru/core/di/providers.dart';
import 'package:koru/core/diagnostics/perf_observer.dart';
import 'package:koru/data/database/app_database.dart';
import 'package:koru/data/local/hive_settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  final hiveSettings = HiveSettingsService();
  await hiveSettings.init();

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
}
