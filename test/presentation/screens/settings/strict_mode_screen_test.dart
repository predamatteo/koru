import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/presentation/screens/settings/sub_screens/strict_mode_screen.dart';
import 'package:koru/presentation/widgets/unlock_challenge_dialog.dart';

/// Lo spegnimento dello strict mode passa dalla **sfida a memoria**, non più
/// dal backdoor code (che resta solo per l'emergency unblock).
///
/// Questi test tengono in piedi due cose:
///
/// 1. **La regressione storica.** Il vecchio dialog backdoor era
///    `showDialog<String>` ma "Annulla" faceva `pop(false)`: il `Completer`
///    interno tentava `false as String?`, il Navigator si corrompeva e dopo
///    2-3 annullamenti l'app si bloccava. Il dialog è cambiato ma la classe di
///    bug no — un route tipizzato in un modo e poppato in un altro — quindi il
///    ciclo apri/annulla ×3 resta.
/// 2. **Il contratto col nativo**, che è nuovo e non lo copre nessun altro:
///    la spec arriva come indici di casella, la risposta torna indietro nella
///    stessa forma, e il token ottenuto finisce davvero in
///    `setStrictModeOptions`.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channelName = 'com.koru/strict_mode';
  const token = 'token-di-prova';

  // Mask corrente lato "native". Parte attiva (allMvp) così lo switch master
  // mostra ON e tentare lo spegnimento apre la sfida.
  late int mask;

  /// Caselle che compongono la sequenza, decise "dal nativo".
  late List<int> sequenceSlots;

  /// Risposta ricevuta dall'ultimo `verifyStrictUnlockChallenge`.
  List<int>? submittedAnswer;

  /// Token passato all'ultimo `setStrictModeOptions`.
  String? usedToken;

  void setMockHandler() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(channelName),
      (call) async {
        switch (call.method) {
          case 'getStrictModeOptions':
            return mask;
          case 'isDeviceAdminActive':
            return true;
          case 'startStrictUnlockChallenge':
            return <String, Object?>{
              'gridSize': 12,
              'columns': 3,
              'sequenceSlots': sequenceSlots,
              'memorizeMs': 4000,
            };
          case 'verifyStrictUnlockChallenge':
            submittedAnswer = (call.arguments['answer'] as List).cast<int>();
            // Come il nativo: token solo se la risposta combacia.
            return _listEquals(submittedAnswer!, sequenceSlots) ? token : null;
          case 'setStrictModeOptions':
            usedToken = call.arguments['unblockToken'] as String?;
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
    sequenceSlots = const [7, 2, 10, 0];
    submittedAnswer = null;
    usedToken = null;
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
      const ProviderScope(child: MaterialApp(home: StrictModeScreen())),
    );
    await tester.pumpAndSettle();
  }

  /// I simboli mostrati nella fase di memorizzazione, in ordine. Cercati dentro
  /// al dialog: la schermata sottostante resta montata.
  List<IconData> readSequence(WidgetTester tester) => tester
      .widgetList<Icon>(
        find.descendant(
          of: find.descendant(
            of: find.byType(UnlockChallengeDialog),
            matching: find.byType(Wrap),
          ),
          matching: find.byType(Icon),
        ),
      )
      .map((icon) => icon.icon!)
      .toList();

  testWidgets('spegnere lo strict mode apre la sfida, non il backdoor code', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('Strict mode is ON'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(find.byType(UnlockChallengeDialog), findsOneWidget);
    expect(find.text('Mostrami la sequenza'), findsOneWidget);
    // Il vecchio gate non deve più comparire su questo percorso.
    expect(find.text('Conferma con backdoor code'), findsNothing);
  });

  testWidgets('annullare la sfida 3 volte non lancia e non spegne strict mode', (
    tester,
  ) async {
    await pumpScreen(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(
        find.byType(UnlockChallengeDialog),
        findsOneWidget,
        reason: 'la sfida deve aprirsi al giro $i',
      );

      await tester.tap(find.widgetWithText(TextButton, 'Lascia stare'));
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'poppare il route con un tipo sbagliato lanciava al giro $i',
      );
      expect(
        find.byType(UnlockChallengeDialog),
        findsNothing,
        reason: 'la sfida deve essere chiusa dopo Lascia stare al giro $i',
      );
    }

    // Annullare non deve mai spegnere la protezione.
    expect(mask, 14);
    expect(usedToken, isNull);
    expect(find.text('Strict mode is ON'), findsOneWidget);
  });

  testWidgets('risolvere la sfida spegne lo strict mode col token del nativo', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrami la sequenza'));
    await tester.pump();
    await tester.pump();

    final sequence = readSequence(tester);
    expect(sequence, hasLength(sequenceSlots.length));

    // Scade il countdown → griglia.
    await tester.pumpAndSettle();
    for (final icon in sequence) {
      await tester.tap(find.byIcon(icon));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // La risposta è tornata al nativo nella forma che si aspetta: le caselle
    // che LUI aveva scelto, nel suo ordine.
    expect(submittedAnswer, sequenceSlots);
    // E il token che ha emesso è finito nella chiamata che abbassa la mask.
    expect(usedToken, token);
    expect(mask, 0);
    expect(find.text('Strict mode is OFF'), findsOneWidget);
  });

  testWidgets('spegnere un singolo bit chiede la mask parziale, non zero', (
    tester,
  ) async {
    await pumpScreen(tester);

    // Il primo SwitchListTile è "Block Settings" (bit 2). Spegnerlo deve
    // portare a 14 & ~2 = 12, non a 0: è la mask che il nativo usa per
    // calibrare la difficoltà e per vincolare il token.
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrami la sequenza'));
    await tester.pump();
    await tester.pump();

    final sequence = readSequence(tester);
    await tester.pumpAndSettle();
    for (final icon in sequence) {
      await tester.tap(find.byIcon(icon));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(mask, 12);
    expect(usedToken, token);
  });

  testWidgets('accendere un bit non chiede nessuna sfida', (tester) async {
    mask = 2; // solo "Block Settings"
    await pumpScreen(tester);

    // Alzare la mask è la direzione fail-secure: deve restare a un tap.
    await tester.tap(find.byType(SwitchListTile).at(1)); // Block Recent apps
    await tester.pumpAndSettle();

    expect(find.byType(UnlockChallengeDialog), findsNothing);
    expect(mask, 2 | 8);
    expect(usedToken, isNull);
  });
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
