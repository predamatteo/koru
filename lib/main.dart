import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:koru/app.dart';
import 'package:koru/core/di/providers.dart';
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
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        hiveSettingsServiceProvider.overrideWithValue(hiveSettings),
      ],
      child: const KoruApp(),
    ),
  );
}
