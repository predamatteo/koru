import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koru/core/router/app_router.dart';
import 'package:koru/platform/blocking_channel.dart';
import 'package:koru/presentation/providers/home_intent_listener.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

/// SEC-12 — il navigation listener apre il prompt del backdoor code quando il
/// native lo richiede (push `requireBackdoorCode` nel warm path, oppure pull
/// `consumePendingBackdoorPrompt` al cold start). Verifica end-to-end Dart:
/// dal MethodCall alla navigazione su `/settings/backdoor`.
///
/// Il secondo gruppo copre il tap sul widget home (`goToRoute` → `/stats`):
/// la schermata dev'essere aggiornata PRIMA di essere aperta.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channelName = 'com.koru/navigation';

  setUpAll(() => registerFallbackValue(0));

  // Risposta che il mock dà a `consumePendingBackdoorPrompt` (pull cold-start).
  bool pendingOnPull = false;

  setUp(() {
    pendingOnPull = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(channelName),
      (call) async {
        if (call.method == 'consumePendingBackdoorPrompt') return pendingOnPull;
        return null;
      },
    );
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(channelName),
      null,
    );
  });

  /// Router minimale che usa il vero [rootNavigatorKey] (quello che il listener
  /// interroga) con le route `/`, `/settings`, `/settings/backdoor`.
  GoRouter buildRouter() => GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (c, s) => const Scaffold(body: Text('HOME')),
          ),
          GoRoute(
            path: KoruRoutes.stats,
            builder: (c, s) => const Scaffold(body: Text('STATS')),
          ),
          GoRoute(
            path: KoruRoutes.settings,
            builder: (c, s) => const Scaffold(body: Text('SETTINGS')),
            routes: [
              GoRoute(
                path: 'backdoor',
                parentNavigatorKey: rootNavigatorKey,
                builder: (c, s) => const Scaffold(body: Text('BACKDOOR_PROMPT')),
              ),
            ],
          ),
        ],
      );

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            // Attiva il listener (come fa KoruApp).
            ref.watch(homeIntentListenerProvider);
            return MaterialApp.router(routerConfig: buildRouter());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Come [pumpApp], ma con un container pre-configurato (mock dei platform
  /// channel + db in-memory) così il refresh dei dati stats è pilotabile.
  Future<void> pumpAppWith(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: Consumer(
          builder: (context, ref, _) {
            ref.watch(homeIntentListenerProvider);
            return MaterialApp.router(routerConfig: buildRouter());
          },
        ),
      ),
    );
    await tester.pump();
  }

  /// Simula il push nativo del metodo [method] sul canale navigation.
  Future<void> invokeFromNative(String method, [Object? arguments]) async {
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      channelName,
      const StandardMethodCodec()
          .encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );
  }

  testWidgets('requireBackdoorCode (warm push) navigates to backdoor prompt',
      (tester) async {
    await pumpApp(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('BACKDOOR_PROMPT'), findsNothing);

    await invokeFromNative('requireBackdoorCode');
    await tester.pumpAndSettle();

    expect(find.text('BACKDOOR_PROMPT'), findsOneWidget);
  });

  testWidgets('consumePendingBackdoorPrompt=true (cold pull) opens prompt',
      (tester) async {
    pendingOnPull = true; // il native segnala una richiesta in sospeso
    await pumpApp(tester);
    // Il pull avviene alla registrazione del listener + post-frame callback.
    await tester.pumpAndSettle();

    expect(find.text('BACKDOOR_PROMPT'), findsOneWidget);
  });

  testWidgets('no pending + no push → stays on home (no false trigger)',
      (tester) async {
    pendingOnPull = false;
    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('BACKDOOR_PROMPT'), findsNothing);
  });

  testWidgets('requireBackdoorCode twice does not stack the prompt',
      (tester) async {
    await pumpApp(tester);
    await invokeFromNative('requireBackdoorCode');
    await tester.pumpAndSettle();
    await invokeFromNative('requireBackdoorCode');
    await tester.pumpAndSettle();

    // Una sola istanza del prompt (la guardia su loc==backdoorRoute evita il
    // doppio push).
    expect(find.text('BACKDOOR_PROMPT'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('goToHomeIfOnLauncher still works (no regression)',
      (tester) async {
    await pumpApp(tester);
    // Naviga a settings, poi il native chiede di tornare a home-se-su-launcher:
    // qui non siamo su launcher quindi non deve succedere nulla di anomalo.
    await invokeFromNative('goToHomeIfOnLauncher');
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  group('tap sul widget home → /stats', () {
    late TestHarness h;

    setUp(() => h = buildTestContainer());
    tearDown(() => h.dispose());

    /// Stub di `getUsageStats` che risponde dopo [delay]. Il ritardo è creato
    /// dentro la zona fake-async del test (è il provider a invocare lo stub),
    /// quindi avanza con `tester.pump(duration)` — un Completer chiuso dal
    /// corpo del test resterebbe invece in una zona che i pump non pompano.
    void stubUsageAfter(Duration delay) {
      when(() => h.blocking.getUsageStats(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((_) async {
        await Future<void>.delayed(delay);
        return const <AppUsageInfo>[];
      });
    }

    testWidgets('aspetta lo screen time fresco prima di aprire la schermata',
        (tester) async {
      stubUsageAfter(const Duration(milliseconds: 400));
      await pumpAppWith(tester, h.container);
      expect(find.text('HOME'), findsOneWidget);

      // NON attendiamo la invoke: l'handler nativo resta in sospeso finché il
      // refresh non finisce — attenderla qui sarebbe un deadlock.
      final handled = invokeFromNative('goToRoute', KoruRoutes.stats);
      await tester.pump();

      // Il dato nativo non è ancora arrivato: la navigazione NON è partita —
      // aprire adesso mostrerebbe i numeri vecchi in cache.
      expect(find.text('STATS'), findsNothing);
      expect(find.text('HOME'), findsOneWidget);

      // Arriva la risposta nativa → il refresh si sblocca e la go() parte.
      // Pump espliciti invece di pumpAndSettle: il refresh lascia in coda i
      // timer del timeout e gli stream Drift appena invalidati, che terrebbero
      // il "settle" irraggiungibile.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1)); // transizione di rotta

      expect(find.text('STATS'), findsOneWidget);
      await handled;
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('naviga comunque se il canale nativo non risponde',
        (tester) async {
      // Il native non risponde MAI (future senza timer: un timer pendente a
      // fine test verrebbe segnalato da flutter_test come leak).
      when(() => h.blocking.getUsageStats(
            startMs: any(named: 'startMs'),
            endMs: any(named: 'endMs'),
          )).thenAnswer((_) => Completer<List<AppUsageInfo>>().future);
      await pumpAppWith(tester, h.container);

      final handled = invokeFromNative('goToRoute', KoruRoutes.stats);
      await tester.pump();
      expect(find.text('STATS'), findsNothing);

      // Scaduto il timeout interno la schermata si apre lo stesso: un canale
      // lento non deve mai lasciare l'utente sulla pagina sbagliata.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1)); // transizione di rotta
      await handled;

      expect(find.text('STATS'), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('route fuori allowlist non naviga', (tester) async {
      stubUsageAfter(Duration.zero);
      await pumpAppWith(tester, h.container);

      await invokeFromNative('goToRoute', 'stats'); // manca lo slash iniziale
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('STATS'), findsNothing);
    });
  });
}
