import 'package:flutter/material.dart';
import 'package:koru/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/unlock_challenge.dart';
import 'package:koru/presentation/widgets/unlock_challenge_dialog.dart';
import 'package:koru/presentation/widgets/unlock_challenge_source.dart';

import '../../_helpers/l10n_test_utils.dart';

/// Copre il giro completo del gate: intro → memorizza → ricostruisci, sia
/// quando l'utente ce la fa sia quando sbaglia o rinuncia.
///
/// La sequenza è casuale e lo stato del dialog è privato, quindi il test la
/// **legge dalla UI** durante la fase di memorizzazione — esattamente come fa
/// l'utente. Comodo effetto collaterale: se un giorno la fase di memorizzazione
/// smettesse di mostrare i simboli, questi test fallirebbero invece di passare
/// su un puzzle impossibile.
void main() {
  /// Monta il dialog e ritorna una funzione per leggere il risultato del pop.
  Future<bool? Function()> showDialogUnderTest(
    WidgetTester tester,
    UnlockChallengeLevel level,
  ) async {
    // La superficie di default (800×600) taglia la griglia del livello più
    // alto: senza spazio i tocchi finirebbero fuori dai tile e i test
    // fallirebbero per un motivo che non c'entra con la logica del gate.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    bool? result;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => UnlockChallengeDialog(
                      source: LocalUnlockChallengeSource(level),
                      action: 'spegnere «Test»',
                    ),
                  );
                  closed = true;
                },
                child: const Text('apri'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    return () => closed ? result : null;
  }

  /// I simboli attualmente mostrati nella fase di memorizzazione, in ordine.
  /// Stanno nel [Wrap], che nella fase di ricostruzione non esiste.
  List<IconData> readSequence(WidgetTester tester) => tester
      .widgetList<Icon>(
        find.descendant(of: find.byType(Wrap), matching: find.byType(Icon)),
      )
      .map((icon) => icon.icon!)
      .toList();

  /// Porta il dialog dalla intro alla fase di ricostruzione, restituendo la
  /// sequenza letta al volo mentre era ancora visibile.
  Future<List<IconData>> startAndMemorize(
    WidgetTester tester,
    UnlockChallengeLevel level,
  ) async {
    await tester.tap(find.text(enL10n.challengeShowSequence));
    // Due pump: la sorgente è asincrona (per lo strict mode c'è un giro sul
    // channel), quindi si passa da una fase di attesa prima di memorizzare.
    await tester.pump();
    await tester.pump();
    final sequence = readSequence(tester);
    expect(sequence, hasLength(level.sequenceLength));
    // Lascia scadere il countdown → fase di ricostruzione.
    await tester.pumpAndSettle();
    expect(find.text(enL10n.challengeRecallTitle), findsOneWidget);
    return sequence;
  }

  testWidgets('intro: non mostra la sequenza finché non la chiedi', (
    tester,
  ) async {
    await showDialogUnderTest(tester, UnlockChallengeLevel.standard);

    expect(find.text(enL10n.challengeIntroTitle), findsOneWidget);
    expect(find.text(enL10n.challengeShowSequence), findsOneWidget);
    // Nessuna griglia e nessuna sequenza prima del via.
    expect(find.byType(GridView), findsNothing);
    expect(find.byType(Wrap), findsNothing);
  });

  testWidgets('sequenza giusta in ordine → il gate si apre', (tester) async {
    final result = await showDialogUnderTest(
      tester,
      UnlockChallengeLevel.standard,
    );
    final sequence = await startAndMemorize(
      tester,
      UnlockChallengeLevel.standard,
    );

    for (final icon in sequence) {
      await tester.tap(find.byIcon(icon));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(result(), isTrue);
  });

  testWidgets('un tocco sbagliato riporta a memorizzare una sfida NUOVA', (
    tester,
  ) async {
    const level = UnlockChallengeLevel.standard;
    final result = await showDialogUnderTest(tester, level);
    final sequence = await startAndMemorize(tester, level);

    // Un simbolo presente in griglia ma che NON è il primo della sequenza.
    final gridIcons = tester
        .widgetList<Icon>(
          find.descendant(
            of: find.byType(GridView),
            matching: find.byType(Icon),
          ),
        )
        .map((icon) => icon.icon!)
        .toList();
    final wrongIcon = gridIcons.firstWhere((i) => i != sequence.first);

    await tester.tap(find.byIcon(wrongIcon));
    await tester.pump(); // registra l'errore
    // Shake e pausa di lettura sono in sequenza: la seconda parte solo quando
    // la prima è finita, quindi vanno scanditi in due pump distinti (uno solo
    // da 800ms lascerebbe la Future.delayed ancora in volo).
    await tester.pump(const Duration(milliseconds: 500)); // shake finito
    await tester.pump(const Duration(milliseconds: 300)); // pausa finita
    await tester.pump(); // richiesta della sfida nuova
    await tester.pump(); // rebuild in fase di memorizzazione

    // Siamo tornati a memorizzare, con il contatore dei tentativi visibile.
    expect(find.text(enL10n.challengeMemorizeTitle), findsOneWidget);
    expect(find.text(enL10n.challengeFailedAttempts(1)), findsOneWidget);
    // Il dialog è ancora aperto: sbagliare non sblocca né chiude.
    expect(result(), isNull);

    // La sfida è stata rigenerata, non ripresentata: la vecchia sequenza non
    // vale più (altrimenti al secondo tentativo basterebbe la memoria del
    // primo e l'attrito sparirebbe).
    final fresh = readSequence(tester);
    expect(fresh, hasLength(level.sequenceLength));
  });

  testWidgets('"Lascia stare" chiude senza sbloccare', (tester) async {
    final result = await showDialogUnderTest(
      tester,
      UnlockChallengeLevel.gentle,
    );

    await tester.tap(find.text(enL10n.challengeGiveUp));
    await tester.pumpAndSettle();

    expect(result(), isFalse);
  });

  testWidgets('la via d\'uscita resta disponibile anche a metà sfida', (
    tester,
  ) async {
    const level = UnlockChallengeLevel.gentle;
    final result = await showDialogUnderTest(tester, level);
    final sequence = await startAndMemorize(tester, level);

    // Un tocco giusto, poi ci ripensa.
    await tester.tap(find.byIcon(sequence.first));
    await tester.pump();
    await tester.tap(find.text(enL10n.challengeGiveUp));
    await tester.pumpAndSettle();

    expect(result(), isFalse);
  });
}
