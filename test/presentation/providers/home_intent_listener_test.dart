import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koru/core/router/app_router.dart';
import 'package:koru/presentation/providers/home_intent_listener.dart';

/// SEC-12 — il navigation listener apre il prompt del backdoor code quando il
/// native lo richiede (push `requireBackdoorCode` nel warm path, oppure pull
/// `consumePendingBackdoorPrompt` al cold start). Verifica end-to-end Dart:
/// dal MethodCall alla navigazione su `/settings/backdoor`.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channelName = 'com.koru/navigation';
  const backdoorRoute = '${KoruRoutes.settings}/backdoor';

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

  /// Simula il push nativo del metodo [method] sul canale navigation.
  Future<void> invokeFromNative(String method) async {
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      channelName,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
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
}
