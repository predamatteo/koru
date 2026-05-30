import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/presentation/screens/settings/sub_screens/strict_mode_screen.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channelName = 'com.koru/strict_mode';

  // Mask corrente lato "native". Parte attiva (allMvp) così lo switch master
  // mostra ON e tentare lo spegnimento apre il dialog backdoor.
  late int mask;

  void setMockHandler() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(channelName),
      (call) async {
        switch (call.method) {
          case 'getStrictModeOptions':
            return mask;
          case 'isDeviceAdminActive':
            return true;
          case 'getRemainingAttempts':
            return 3;
          case 'getLockoutRemainingMs':
            return 0;
          case 'setStrictModeOptions':
            mask = call.arguments['mask'] as int;
            return null;
          default:
            return null;
        }
      },
    );
  }

  setUp(() {
    mask = 14; // StrictModeOption.allMvp
    setMockHandler();
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(channelName),
      null,
    );
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: StrictModeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Regressione: il dialog backdoor è `showDialog<String>`. Quando "Annulla"
  // chiudeva il route con `pop(false)` (un bool), il Completer<String?> interno
  // faceva `false as String?` → TypeError dentro il Navigator, corrompendone
  // lo stato. Dopo 2-3 annullamenti l'app si bloccava (ANR). Qui ripetiamo il
  // ciclo apri-dialog → Annulla 3 volte e pretendiamo zero eccezioni e che la
  // strict mode resti attiva.
  testWidgets('annullare il dialog backdoor 3 volte non lancia e non spegne '
      'strict mode', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Strict mode is ON'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      // Lo switch master è il primo Switch della pagina (dentro la Card).
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(
        find.text('Conferma con backdoor code'),
        findsOneWidget,
        reason: 'il dialog deve aprirsi al giro $i',
      );

      await tester.tap(find.widgetWithText(TextButton, 'Annulla'));
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'pop(false) su Route<String> lanciava un TypeError al giro $i',
      );
      expect(
        find.text('Conferma con backdoor code'),
        findsNothing,
        reason: 'il dialog deve essere chiuso dopo Annulla al giro $i',
      );
    }

    // Annullare non deve mai spegnere la protezione.
    expect(mask, 14);
    expect(find.text('Strict mode is ON'), findsOneWidget);
  });
}
