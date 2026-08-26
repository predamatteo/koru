import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/platform/blocking_channel.dart';
import 'package:koru/presentation/providers/app_limits_provider.dart';
import 'package:koru/presentation/providers/app_list_provider.dart';
import 'package:koru/presentation/screens/settings/sub_screens/app_limits_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_helpers/provider_test_utils.dart';

InstalledAppInfo _app(String pkg, String label) =>
    InstalledAppInfo(packageName: pkg, label: label);

class _StubAppLimitsNotifier extends AppLimitsNotifier {
  _StubAppLimitsNotifier(this._limits);

  final Map<String, AppLimitConfig> _limits;

  /// Cattura le scritture invece di andare sul canale nativo.
  static final saved = <String, AppLimitConfig?>{};

  @override
  Future<Map<String, AppLimitConfig>> build() async => _limits;

  @override
  Future<void> setLimit(
    String packageName,
    int minutes, {
    bool? strict,
    bool? challengeLock,
  }) async {
    saved[packageName] = AppLimitConfig(
      minutes: minutes,
      strict: strict ?? true,
      challengeLock: challengeLock ?? true,
    );
  }

  @override
  Future<void> clear(String packageName) async {
    saved[packageName] = null;
  }
}

TestHarness _harness({
  List<InstalledAppInfo> apps = const [],
  Map<String, AppLimitConfig> limits = const {},
  Map<String, int> usageMs = const {},
}) {
  final h = buildTestContainer(extra: [
    installedAppsProvider.overrideWith((ref) async => apps),
    launcherPackagesProvider.overrideWith((ref) async => const <String>{}),
    todayUsageMsByPackageProvider.overrideWith((ref) async => usageMs),
    appLimitsProvider.overrideWith(() => _StubAppLimitsNotifier(limits)),
  ]);
  // Le icone si caricano on-demand per riga; senza stub il mock esplode.
  when(() => h.blocking.getAppIcon(any())).thenAnswer((_) async => null);
  // `unlockChallengeLevelProvider` legge il livello da Hive.
  when(() => h.hive.get<String>(any(), any())).thenReturn(null);
  // `cachedAppInventoryProvider` (fallback disco di `pickerAppsProvider`)
  // legge una String NON nullable: senza stub mocktail ritorna null e il
  // build esplode con un TypeError invece che con un mock non stubato.
  when(() => h.hive.getString(any(), any())).thenReturn('');
  return h;
}

Widget _wrap(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AppLimitsScreen()),
    );

/// Pump espliciti: la schermata tiene vivi provider che riprogrammano lavoro,
/// e `pumpAndSettle` non convergerebbe.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  setUp(_StubAppLimitsNotifier.saved.clear);

  group('sortForDisplay', () {
    final apps = [
      _app('com.a', 'Alpha'),
      _app('com.b', 'Bravo'),
      _app('com.c', 'Charlie'),
      _app('com.d', 'Delta'),
    ];

    test('ordina per uso di oggi decrescente', () {
      final out = sortAppsForLimits(
        apps: apps,
        limits: const {},
        usageMs: const {'com.a': 60000, 'com.c': 900000, 'com.d': 300000},
      );
      expect(
        out.map((a) => a.packageName),
        ['com.c', 'com.d', 'com.a', 'com.b'],
      );
    });

    test('le app con un limite restano in cima anche se non usate', () {
      // È il motivo per cui la schermata esiste: sprofondare un cap appena
      // messo sotto trenta app non correlate la trasformerebbe da editor dei
      // propri limiti a semplice elenco.
      final out = sortAppsForLimits(
        apps: apps,
        limits: const {'com.b': AppLimitConfig(minutes: 30, strict: true)},
        usageMs: const {'com.a': 999999, 'com.c': 500000},
      );
      expect(out.first.packageName, 'com.b');
    });

    test('fra i limiti attivi viene prima il cap più stretto', () {
      final out = sortAppsForLimits(
        apps: apps,
        limits: const {
          'com.a': AppLimitConfig(minutes: 120, strict: true),
          'com.b': AppLimitConfig(minutes: 15, strict: true),
        },
        usageMs: const {},
      );
      expect(out.take(2).map((a) => a.packageName), ['com.b', 'com.a']);
    });

    test('a parità di uso resta l\'ordine alfabetico', () {
      // A zero minuti sono la maggioranza: senza questo tie-break la lista si
      // riordinerebbe a ogni rebuild.
      final out = sortAppsForLimits(
        apps: [_app('com.z', 'Zulu'), _app('com.m', 'Mike')],
        limits: const {},
        usageMs: const {},
      );
      expect(out.map((a) => a.label), ['Mike', 'Zulu']);
    });
  });

  group('paginazione', () {
    testWidgets('dipinge le prime 25 righe, non tutte', (tester) async {
      final apps = [
        for (var i = 0; i < 60; i++)
          _app('com.app$i', 'App ${i.toString().padLeft(2, '0')}'),
      ];
      final h = _harness(
        apps: apps,
        // Uso decrescente con l'indice: App 00 è la più usata.
        usageMs: {for (var i = 0; i < 60; i++) 'com.app$i': (60 - i) * 60000},
      );
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await _settle(tester);

      // La prima pagina c'è...
      expect(find.text('App 00'), findsOneWidget);
      // ...e la riga #40 no: non è stata nemmeno costruita.
      expect(find.text('App 40'), findsNothing);
    });

    testWidgets('la ricerca raggiunge le app oltre il taglio', (tester) async {
      // Il filtro lavora sull'elenco INTERO: se lavorasse sulla pagina,
      // l'app che stai cercando sparirebbe proprio perché è in fondo.
      final apps = [
        for (var i = 0; i < 60; i++)
          _app('com.app$i', 'App ${i.toString().padLeft(2, '0')}'),
      ];
      final h = _harness(
        apps: apps,
        usageMs: {for (var i = 0; i < 60; i++) 'com.app$i': (60 - i) * 60000},
      );
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'App 55');
      await _settle(tester);

      // Ancorato alla ListView: il testo compare anche nel campo di ricerca.
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('App 55'),
        ),
        findsOneWidget,
      );
    });
  });

  group('gate della sfida', () {
    Future<void> openDialogFor(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await _settle(tester);
    }

    testWidgets('abbassare il cap non chiede la sfida', (tester) async {
      // Solo la direzione che INDEBOLISCE è gateata: stringere una protezione
      // deve restare gratis.
      final h = _harness(
        apps: [_app('com.a', 'Alpha')],
        limits: const {
          'com.a': AppLimitConfig(minutes: 60, strict: true),
        },
      );
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await _settle(tester);
      await openDialogFor(tester, 'Alpha');

      // 15m < 60m ⇒ rafforza.
      await tester.tap(find.text('15m'));
      await _settle(tester);
      await tester.tap(find.text('Save'));
      await _settle(tester);

      expect(find.textContaining('ricostruire una sequenza'), findsNothing);
      expect(_StubAppLimitsNotifier.saved['com.a']?.minutes, 15);
    });

    testWidgets('alzare il cap di un limite protetto chiede la sfida',
        (tester) async {
      final h = _harness(
        apps: [_app('com.a', 'Alpha')],
        limits: const {
          'com.a': AppLimitConfig(minutes: 15, strict: true),
        },
      );
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await _settle(tester);
      await openDialogFor(tester, 'Alpha');

      await tester.tap(find.text('120m'));
      await _settle(tester);
      await tester.tap(find.text('Save'));
      await _settle(tester);

      expect(find.textContaining('ricostruire una sequenza'), findsOneWidget);
      // Non salvato: la sfida non è ancora stata superata.
      expect(_StubAppLimitsNotifier.saved, isEmpty);
    });

    testWidgets('con challengeLock spento non chiede nulla', (tester) async {
      final h = _harness(
        apps: [_app('com.a', 'Alpha')],
        limits: const {
          'com.a': AppLimitConfig(
            minutes: 15,
            strict: true,
            challengeLock: false,
          ),
        },
      );
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await _settle(tester);
      await openDialogFor(tester, 'Alpha');

      await tester.tap(find.text('120m'));
      await _settle(tester);
      await tester.tap(find.text('Save'));
      await _settle(tester);

      expect(find.textContaining('ricostruire una sequenza'), findsNothing);
      expect(_StubAppLimitsNotifier.saved['com.a']?.minutes, 120);
    });

    testWidgets('impostare un limite la PRIMA volta non chiede la sfida',
        (tester) async {
      final h = _harness(apps: [_app('com.a', 'Alpha')]);
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await _settle(tester);
      await openDialogFor(tester, 'Alpha');
      await tester.tap(find.text('Save'));
      await _settle(tester);

      expect(find.textContaining('ricostruire una sequenza'), findsNothing);
      expect(_StubAppLimitsNotifier.saved['com.a']?.minutes, 30);
    });

    testWidgets('spegnere il lock dal dialog non aggira il gate',
        (tester) async {
      // Il controllo legge la config SALVATA: se leggesse quella che esce dal
      // dialog, basterebbe spegnere l'interruttore lì dentro per uscire senza
      // sfida — cioè la protezione si disattiverebbe da sé.
      final h = _harness(
        apps: [_app('com.a', 'Alpha')],
        limits: const {
          'com.a': AppLimitConfig(minutes: 30, strict: true),
        },
      );
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await _settle(tester);
      await openDialogFor(tester, 'Alpha');

      await tester.tap(find.text('Blocco per le sfide'));
      await _settle(tester);
      await tester.tap(find.text('Save'));
      await _settle(tester);

      expect(find.textContaining('ricostruire una sequenza'), findsOneWidget);
      expect(_StubAppLimitsNotifier.saved, isEmpty);
    });

    testWidgets('rimuovere un limite protetto chiede la sfida', (tester) async {
      final h = _harness(
        apps: [_app('com.a', 'Alpha')],
        limits: const {
          'com.a': AppLimitConfig(minutes: 30, strict: true),
        },
      );
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.container));
      await _settle(tester);
      await openDialogFor(tester, 'Alpha');

      await tester.tap(find.text('Remove'));
      await _settle(tester);

      expect(find.textContaining('ricostruire una sequenza'), findsOneWidget);
      expect(_StubAppLimitsNotifier.saved, isEmpty);
    });
  });
}
