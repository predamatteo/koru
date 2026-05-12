import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koru/core/di/providers.dart';
import 'package:koru/data/database/app_database.dart';
import 'package:koru/data/local/hive_settings_service.dart';
import 'package:koru/platform/blocking_channel.dart';
import 'package:koru/platform/permission_channel.dart';
import 'package:koru/platform/platform_channel_service.dart';
import 'package:koru/platform/profile_channel.dart';
import 'package:koru/platform/service_event_channel.dart';
import 'package:koru/platform/strict_mode_channel.dart';
import 'package:mocktail/mocktail.dart';

/// Mock di [HiveSettingsService] — copre tutti gli helper tipizzati.
class MockHive extends Mock implements HiveSettingsService {}

/// Mock della facade [PlatformChannelService] — combinato con i sotto-mock.
class MockPlatform extends Mock implements PlatformChannelService {}

class MockBlocking extends Mock implements BlockingChannel {}

class MockProfileChannel extends Mock implements ProfileChannel {}

class MockStrictMode extends Mock implements StrictModeChannel {}

class MockPermission extends Mock implements PermissionChannel {}

class MockEvents extends Mock implements ServiceEventChannel {}

/// Bundle restituito da [buildTestContainer] — espone tutti i mock e il
/// container, così i test possono fare `harness.hive` / `harness.blocking`
/// senza variabili sparse.
class TestHarness {
  TestHarness({
    required this.container,
    required this.db,
    required this.hive,
    required this.platform,
    required this.blocking,
    required this.strict,
    required this.profileCh,
    required this.events,
    required this.permission,
  });

  final ProviderContainer container;
  final AppDatabase db;
  final MockHive hive;
  final MockPlatform platform;
  final MockBlocking blocking;
  final MockStrictMode strict;
  final MockProfileChannel profileCh;
  final MockEvents events;
  final MockPermission permission;

  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

/// Crea un [ProviderContainer] pre-configurato con un db Drift in-memory
/// reale + mock per Hive e per la facade dei platform channel.
///
/// Pattern consigliato in test:
/// ```dart
/// final h = buildTestContainer();
/// addTearDown(h.dispose);
/// final value = h.container.read(myProvider);
/// ```
TestHarness buildTestContainer({List<Override> extra = const []}) {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final hive = MockHive();
  final platform = MockPlatform();
  final blocking = MockBlocking();
  final strict = MockStrictMode();
  final profileCh = MockProfileChannel();
  final permission = MockPermission();
  final events = MockEvents();

  // Wire i sotto-mock alla facade.
  when(() => platform.blocking).thenReturn(blocking);
  when(() => platform.strictMode).thenReturn(strict);
  when(() => platform.profile).thenReturn(profileCh);
  when(() => platform.permission).thenReturn(permission);
  when(() => platform.events).thenReturn(events);

  final container = ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    hiveSettingsServiceProvider.overrideWithValue(hive),
    platformChannelServiceProvider.overrideWithValue(platform),
    ...extra,
  ]);

  return TestHarness(
    container: container,
    db: db,
    hive: hive,
    platform: platform,
    blocking: blocking,
    strict: strict,
    profileCh: profileCh,
    events: events,
    permission: permission,
  );
}

/// Helper per i test che ascoltano un provider — registra un listener no-op
/// in modo che il container "tenga in vita" l'observer (utile per
/// AsyncNotifier dove leggere `.future` può non bastare a innescare la build).
void keepProviderAlive<T>(ProviderContainer container, ProviderListenable<T> provider) {
  container.listen<T>(provider, (_, _) {}, fireImmediately: true);
}
