import '../../domain/entities/unlock_challenge.dart';
import '../../platform/strict_mode_channel.dart';

/// Da dove arriva una sfida e chi ne certifica la soluzione.
///
/// Esistono due sorgenti perché le due protezioni di Koru hanno autorità
/// diverse:
///
/// - i **profili** vivono su Drift e le scrivono solo il Dart, quindi il gate
///   può stare tutto qui ([LocalUnlockChallengeSource]);
/// - lo **strict mode** ha un gate nativo (SEC-01: `setStrictModeOptions`
///   rifiuta ogni downgrade senza un token monouso emesso da Kotlin), quindi
///   la sfida deve essere emessa e verificata di là
///   ([StrictModeUnlockChallengeSource]).
///
/// In entrambi i casi il Dart valida **tap per tap** per dare feedback
/// immediato — può farlo perché la sequenza gli è comunque nota, deve
/// disegnarla. [confirm] è il sigillo finale, e solo per lo strict mode ha
/// qualcuno dall'altra parte che può dire di no.
abstract class UnlockChallengeSource {
  /// Una sfida nuova, o il motivo per cui adesso non se ne può avere una.
  Future<ChallengeRequest> next();

  /// L'utente ha completato la sequenza. True se il gate si apre.
  Future<bool> confirm(UnlockChallenge challenge);
}

sealed class ChallengeRequest {
  const ChallengeRequest();
}

class ChallengeReady extends ChallengeRequest {
  const ChallengeReady(this.challenge);
  final UnlockChallenge challenge;
}

/// Nessuna sfida disponibile: cooldown nativo, o uno stato che non consente il
/// downgrade. [message] è già scritto per essere letto dall'utente.
class ChallengeBlocked extends ChallengeRequest {
  const ChallengeBlocked(this.message);
  final String message;
}

/// Sorgente locale: genera e approva tutto in Dart. Usata per i profili.
class LocalUnlockChallengeSource implements UnlockChallengeSource {
  const LocalUnlockChallengeSource(this.level);

  final UnlockChallengeLevel level;

  @override
  Future<ChallengeRequest> next() async =>
      ChallengeReady(generateUnlockChallenge(level));

  /// Sempre true: la correttezza è già stata verificata a ogni tocco e non c'è
  /// nessun'altra autorità da consultare.
  @override
  Future<bool> confirm(UnlockChallenge challenge) async => true;
}

/// Sorgente dello strict mode: la sequenza la sceglie Kotlin, che è anche
/// l'unico a poter emettere il token che sblocca `setStrictModeOptions`.
///
/// Non è opzionale e non guarda le impostazioni dell'utente: qui la sfida ha
/// **sostituito** il backdoor code sul percorso normale, non è l'attrito
/// configurabile dei profili. Il codice resta come rete di sicurezza, solo per
/// l'emergency unblock.
class StrictModeUnlockChallengeSource implements UnlockChallengeSource {
  StrictModeUnlockChallengeSource({
    required this.channel,
    required this.targetMask,
  });

  final StrictModeChannel channel;

  /// La mask a cui si vuole arrivare. Il nativo ci calibra sopra la difficoltà
  /// (uscire del tutto costa più che allentare un bit) e ci vincola il token.
  final int targetMask;

  /// Token monouso ottenuto da una [confirm] riuscita. Va passato subito a
  /// `setStrictModeOptions`: vale 60 secondi e solo per [targetMask].
  String? unblockToken;

  @override
  Future<ChallengeRequest> next() async {
    final outcome = await channel.startStrictUnlockChallenge(targetMask);
    return switch (outcome) {
      StrictUnlockIssued(:final spec) => ChallengeReady(
        buildUnlockChallengeForSlots(
          gridSize: spec.gridSize,
          columns: spec.columns,
          memorizeDuration: spec.memorizeDuration,
          sequenceSlots: spec.sequenceSlots,
        ),
      ),
      StrictUnlockCooldown(:final remainingMs) => ChallengeBlocked(
        'Troppi tentativi falliti di fila. Riprova fra '
        '${_seconds(remainingMs)}.',
      ),
      // Include NOT_A_DOWNGRADE (la mask non spegne nulla) e gli errori di
      // lettura della mask: in entrambi i casi non si procede. Fail-secure:
      // se non riusciamo a farci autorizzare, lo strict mode resta com'è.
      StrictUnlockUnavailable() => const ChallengeBlocked(
        'Non è stato possibile avviare la verifica. Riprova fra un momento.',
      ),
    };
  }

  @override
  Future<bool> confirm(UnlockChallenge challenge) async {
    final token = await channel.verifyStrictUnlockChallenge(
      challenge.sequenceSlots,
    );
    unblockToken = token;
    return token != null;
  }

  static String _seconds(int ms) {
    final s = (ms / 1000).ceil();
    return s == 1 ? 'un secondo' : '$s secondi';
  }
}
