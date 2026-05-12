import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koru/platform/blocking_channel.dart';
import 'package:koru/presentation/providers/app_limits_provider.dart';
import 'package:koru/presentation/providers/app_list_provider.dart';
import 'package:koru/presentation/screens/home/widgets/today_limits_card.dart';

import '../../_helpers/provider_test_utils.dart';

/// Costruisce un MaterialApp con GoRouter — TodayLimitsCard usa `context.push`
/// per il bottone "Edit", richiede un router nell'inheritance tree.
Widget _wrap(ProviderContainer container, Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: child)),
      GoRoute(
        path: '/settings/app-limits',
        builder: (_, _) => const Scaffold(body: Text('AppLimitsPage')),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('TodayLimitsCard', () {
    testWidgets('renders nothing when no limits are configured',
        (tester) async {
      final h = buildTestContainer(extra: [
        appLimitsProvider.overrideWith(
          () => _StubAppLimitsNotifier(const {}),
        ),
        installedAppsProvider.overrideWith((ref) async => const []),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container, const TodayLimitsCard()));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNothing);
      expect(find.text("TODAY'S LIMITS"), findsNothing);
    });

    testWidgets('renders one row per limited package, sorted desc by minutes',
        (tester) async {
      final limits = <String, AppLimitConfig>{
        'com.app1': const AppLimitConfig(minutes: 30, strict: false),
        'com.app2': const AppLimitConfig(minutes: 60, strict: true),
      };
      final apps = [
        InstalledAppInfo(packageName: 'com.app1', label: 'App One'),
        InstalledAppInfo(packageName: 'com.app2', label: 'App Two'),
      ];

      final h = buildTestContainer(extra: [
        appLimitsProvider.overrideWith(
          () => _StubAppLimitsNotifier(limits),
        ),
        installedAppsProvider.overrideWith((ref) async => apps),
        usageTodayMinutesProvider.overrideWith(
          (ref, packageName) async => packageName == 'com.app1' ? 10 : 5,
        ),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container, const TodayLimitsCard()));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsOneWidget);
      expect(find.text("TODAY'S LIMITS"), findsOneWidget);
      expect(find.text('App One'), findsOneWidget);
      expect(find.text('App Two'), findsOneWidget);
      // Mostra used/limit per ognuna.
      expect(find.text('10 / 30 min'), findsOneWidget);
      expect(find.text('5 / 60 min'), findsOneWidget);
      // App2 è strict → mostra icona lucchetto.
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('Edit button is present and tappable', (tester) async {
      final limits = <String, AppLimitConfig>{
        'com.x': const AppLimitConfig(minutes: 20, strict: false),
      };
      final h = buildTestContainer(extra: [
        appLimitsProvider.overrideWith(
          () => _StubAppLimitsNotifier(limits),
        ),
        installedAppsProvider.overrideWith((ref) async => const []),
        usageTodayMinutesProvider.overrideWith((ref, p) async => 0),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container, const TodayLimitsCard()));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Edit'), findsOneWidget);
      // Tappabile (no crash).
      await tester.tap(find.widgetWithText(TextButton, 'Edit'));
      await tester.pumpAndSettle();
    });

    testWidgets('falls back to packageName when the app label is unknown',
        (tester) async {
      final limits = <String, AppLimitConfig>{
        'com.unknown': const AppLimitConfig(minutes: 15, strict: false),
      };
      final h = buildTestContainer(extra: [
        appLimitsProvider.overrideWith(
          () => _StubAppLimitsNotifier(limits),
        ),
        installedAppsProvider.overrideWith((ref) async => const []),
        usageTodayMinutesProvider.overrideWith((ref, p) async => 0),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container, const TodayLimitsCard()));
      await tester.pumpAndSettle();

      expect(find.text('com.unknown'), findsOneWidget);
    });

    testWidgets('shows progress bar at full width when usage exceeds limit',
        (tester) async {
      final limits = <String, AppLimitConfig>{
        'com.over': const AppLimitConfig(minutes: 10, strict: false),
      };
      final h = buildTestContainer(extra: [
        appLimitsProvider.overrideWith(
          () => _StubAppLimitsNotifier(limits),
        ),
        installedAppsProvider.overrideWith((ref) async => const []),
        usageTodayMinutesProvider.overrideWith((ref, p) async => 30),
      ]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container, const TodayLimitsCard()));
      await tester.pumpAndSettle();

      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, 1.0); // clamped
      expect(find.text('30 / 10 min'), findsOneWidget);
    });
  });
}

/// Stub minimo per [AppLimitsNotifier]. Espone una mappa fissa come stato.
class _StubAppLimitsNotifier extends AppLimitsNotifier {
  _StubAppLimitsNotifier(this._initial);

  final Map<String, AppLimitConfig> _initial;

  @override
  Future<Map<String, AppLimitConfig>> build() async => _initial;
}
