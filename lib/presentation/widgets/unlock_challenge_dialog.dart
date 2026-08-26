import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/koru_colors.dart';
import '../../domain/entities/unlock_challenge.dart';
import '../../platform/strict_mode_channel.dart';
import '../providers/unlock_challenge_provider.dart';
import 'unlock_challenge_glyphs.dart';
import 'unlock_challenge_source.dart';

/// Gate di attrito per i **profili**: da mettere davanti a ogni azione che
/// indebolisce una protezione (spegnere un profilo, cancellarlo, togliergli app
/// o siti).
///
/// Ritorna `true` se l'utente ha superato la sfida — che c'è **sempre**: il
/// livello si sceglie, spegnerlo no (vedi [UnlockChallengeLevel]). Ritorna
/// `false` se ha annullato — e annullare è la direzione SICURA (la protezione
/// resta attiva), quindi è volutamente facile. Non serve intrappolare nessuno:
/// chi vuole davvero uscire fa il puzzle, chi stava solo cedendo all'impulso ha
/// già ottenuto la sua pausa.
///
/// Per lo strict mode serve [requireStrictUnlockChallenge]: là la sfida non è
/// opzionale e la verifica è nativa.
///
/// [action] completa la frase "Per `<action>` devi prima ricostruire una
/// sequenza di simboli", es. `'spegnere «Sera senza social»'`.
Future<bool> requireUnlockChallenge(
  BuildContext context,
  WidgetRef ref, {
  required String action,
}) async {
  final level = ref.read(unlockChallengeLevelProvider);
  return _showChallenge(
    context,
    source: LocalUnlockChallengeSource(level),
    action: action,
  );
}

/// Gate di attrito per i **limiti giornalieri** con `challengeLock` attivo.
///
/// Differenza dal gate dei profili: qui l'interruttore è **per-app**, e vive
/// nel dialog del limite. Il livello del puzzle resta però quello globale —
/// chi ha chiesto un puzzle più duro lo vuole ovunque.
///
/// La direzione gateata resta solo quella che INDEBOLISCE: alzare i minuti,
/// togliere il limite, spegnere lo strict, spegnere il lock stesso. Abbassare
/// il cap o accendere una protezione è sempre gratis.
Future<bool> requireLimitUnlockChallenge(
  BuildContext context,
  WidgetRef ref, {
  required String action,
}) async {
  final level = ref.read(unlockChallengeLevelProvider);
  return _showChallenge(
    context,
    source: LocalUnlockChallengeSource(level),
    action: action,
  );
}

/// Gate dello **strict mode**: sostituisce il backdoor code sul percorso
/// normale di downgrade della mask.
///
/// Ritorna il token monouso da passare a
/// [StrictModeChannel.setStrictModeOptions], oppure `null` se l'utente ha
/// rinunciato o il nativo non ha autorizzato. Il token vale ~60 secondi e solo
/// per [targetMask]: va speso subito.
///
/// A differenza di [requireUnlockChallenge] non consulta le impostazioni
/// dell'utente — qui la sfida è obbligatoria, è l'unica chiave rimasta sul
/// percorso normale (il codice resta solo per l'emergency unblock).
Future<String?> requireStrictUnlockChallenge(
  BuildContext context, {
  required StrictModeChannel channel,
  required int targetMask,
  required String action,
}) async {
  final source = StrictModeUnlockChallengeSource(
    channel: channel,
    targetMask: targetMask,
  );
  final passed = await _showChallenge(
    context,
    source: source,
    action: action,
  );
  return passed ? source.unblockToken : null;
}

Future<bool> _showChallenge(
  BuildContext context, {
  required UnlockChallengeSource source,
  required String action,
}) async {
  final passed = await showDialog<bool>(
    context: context,
    // Niente dismiss dal barrier: uscire deve essere una scelta esplicita
    // (il pulsante), non un tocco distratto a lato.
    barrierDismissible: false,
    builder: (_) => UnlockChallengeDialog(source: source, action: action),
  );
  return passed ?? false;
}

enum _Phase { intro, loading, memorize, recall, blocked }

class UnlockChallengeDialog extends StatefulWidget {
  const UnlockChallengeDialog({
    super.key,
    required this.source,
    required this.action,
  });

  final UnlockChallengeSource source;
  final String action;

  @override
  State<UnlockChallengeDialog> createState() => _UnlockChallengeDialogState();
}

class _UnlockChallengeDialogState extends State<UnlockChallengeDialog>
    with TickerProviderStateMixin {
  /// `null` finché la prima sfida non è arrivata dalla sorgente (che può essere
  /// asincrona: per lo strict mode c'è di mezzo un giro sul channel).
  UnlockChallenge? _challenge;
  _Phase _phase = _Phase.intro;

  /// Quanti glifi della sequenza sono già stati indovinati in questo tentativo.
  int _progress = 0;

  /// Tentativi falliti. Mostrato all'utente: vedere il contatore salire è parte
  /// dell'attrito (rende visibile "quanto la stai volendo").
  int _failedAttempts = 0;

  /// True nella finestra di feedback dopo un tocco sbagliato: la griglia è
  /// congelata (niente tocchi) mentre l'animazione di errore gira.
  bool _showingError = false;

  String _blockedMessage = '';

  // NON `late final` con inizializzatore: con [TickerProviderStateMixin] un
  // controller creato pigramente viene istanziato al primo accesso, e se
  // l'utente chiude il dialog dalla intro (senza mai far partire un'animazione)
  // quel primo accesso è `dispose()` → si crea un Ticker su un element già
  // deactivated e Flutter asserisce ("Looking up a deactivated widget's
  // ancestor is unsafe"). Costruirli in initState li rende sempre già vivi.
  late final AnimationController _countdown;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    // La durata vera arriva con ogni sfida (le spec native portano la loro):
    // qui serve solo un valore non nullo per costruire il controller.
    _countdown = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addStatusListener(_onCountdownStatus);
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    // removeStatusListener prima del dispose: il controller può notificare
    // durante il teardown e il listener fa setState.
    _countdown
      ..removeStatusListener(_onCountdownStatus)
      ..dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onCountdownStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    if (_phase != _Phase.memorize) return;
    setState(() => _phase = _Phase.recall);
  }

  /// Chiede una sfida NUOVA alla sorgente e riparte dalla memorizzazione.
  ///
  /// Chiedere invece di ripresentare la stessa è deliberato su entrambi i
  /// fronti: lato UX, se dopo un errore rivedessi lo stesso puzzle al terzo
  /// tentativo lo risolveresti a memoria muscolare; lato strict mode è pure
  /// obbligatorio, perché ogni verifica — anche fallita — brucia la sfida sul
  /// nativo.
  Future<void> _requestChallenge() async {
    setState(() => _phase = _Phase.loading);
    final request = await widget.source.next();
    if (!mounted) return;
    switch (request) {
      case ChallengeReady(:final challenge):
        setState(() {
          _challenge = challenge;
          _progress = 0;
          _showingError = false;
          _phase = _Phase.memorize;
        });
        _countdown
          ..duration = challenge.memorizeDuration
          ..forward(from: 0);
      case ChallengeBlocked(:final message):
        setState(() {
          _blockedMessage = message;
          _phase = _Phase.blocked;
        });
    }
  }

  /// Sincrono di proposito. Le vibrazioni sono fire-and-forget
  /// (`.ignore()`): aspettarle metterebbe un round-trip di platform channel
  /// sul percorso critico di OGNI tocco, e un device che non risponde
  /// congelerebbe la griglia proprio mentre l'utente la sta usando.
  void _onGlyphTap(String glyphId) {
    final challenge = _challenge;
    if (challenge == null || _showingError) return;

    if (challenge.isCorrectNext(_progress, glyphId)) {
      HapticFeedback.selectionClick().ignore();
      final next = _progress + 1;
      if (next < challenge.length) {
        setState(() => _progress = next);
        return;
      }
      // Sequenza completa: la sorgente ha l'ultima parola.
      HapticFeedback.mediumImpact().ignore();
      _confirm(challenge);
      return;
    }

    // Sbagliato: feedback, poi si ricomincia da capo con una sfida nuova.
    HapticFeedback.heavyImpact().ignore();
    setState(() {
      _showingError = true;
      _failedAttempts++;
    });
    _playErrorFeedback();
  }

  Future<void> _confirm(UnlockChallenge challenge) async {
    setState(() => _phase = _Phase.loading);
    final granted = await widget.source.confirm(challenge);
    if (!mounted) return;
    if (granted) {
      Navigator.of(context).pop(true);
      return;
    }
    // I tocchi erano giusti (li abbiamo validati noi) ma la sorgente ha detto
    // no: per lo strict mode significa sfida scaduta lato nativo, o cooldown
    // scattato nel frattempo. Non è colpa dell'utente, quindi lo diciamo.
    setState(() {
      _blockedMessage =
          'La verifica è scaduta prima che finissi. Puoi ricominciare.';
      _phase = _Phase.blocked;
    });
  }

  Future<void> _playErrorFeedback() async {
    await _shake.forward(from: 0);
    if (!mounted) return;
    // Pausa di lettura: senza, la griglia si rigenererebbe nello stesso
    // istante in cui finisce lo shake e sembrerebbe un glitch invece di un
    // "no, ricomincia".
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    await _requestChallenge();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: KoruColors.backgroundBase,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(child: _body()),
                ),
              ),
              if (_failedAttempts > 0 && _phase != _Phase.blocked)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _failedAttempts == 1
                        ? 'Un tentativo andato storto. Nessuna fretta.'
                        : '$_failedAttempts tentativi andati storti. Nessuna fretta.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: KoruColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: KoruColors.textSecondary,
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Lascia stare'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final challenge = _challenge;
    return switch (_phase) {
      _Phase.intro => _IntroPane(
        action: widget.action,
        onStart: _requestChallenge,
      ),
      _Phase.loading => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      _Phase.blocked => _BlockedPane(
        message: _blockedMessage,
        onRetry: _requestChallenge,
      ),
      // challenge non può essere null in queste due fasi (ci si arriva solo da
      // _requestChallenge, che la imposta prima di cambiare fase); il fallback
      // allo spinner evita comunque un `!` che crasherebbe dentro al gate.
      _Phase.memorize when challenge != null => _MemorizePane(
        challenge: challenge,
        countdown: _countdown,
      ),
      _Phase.recall when challenge != null => _RecallPane(
        challenge: challenge,
        progress: _progress,
        showingError: _showingError,
        shake: _shake,
        onTap: _onGlyphTap,
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _header(BuildContext context) {
    final (title, subtitle) = switch (_phase) {
      _Phase.intro => ('Un momento', 'Prima di indebolire la protezione.'),
      _Phase.loading => ('Un momento', ''),
      _Phase.memorize => (
        'Memorizza',
        'Questi simboli, in questo ordine. Poi spariscono.',
      ),
      _Phase.recall => (
        'Ricostruisci',
        'Toccali nell\'ordine di prima. Attenzione ai sosia.',
      ),
      _Phase.blocked => ('Non adesso', ''),
    };
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: KoruColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: KoruColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Fase 1: intro ──────────────────────────────────────────────────────────

class _IntroPane extends StatelessWidget {
  const _IntroPane({required this.action, required this.onStart});

  final String action;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: KoruColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.psychology_outlined,
            size: 42,
            color: KoruColors.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Per $action devi prima ricostruire una sequenza di simboli.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: KoruColors.textPrimary,
            fontSize: 16,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Te li mostriamo per qualche secondo, poi li ritrovi in una griglia '
          'piena di simboli quasi identici.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: KoruColors.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: onStart,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: KoruColors.primary,
            foregroundColor: KoruColors.onPrimary,
          ),
          child: const Text('Mostrami la sequenza'),
        ),
      ],
    );
  }
}

// ─── Fase alternativa: nessuna sfida disponibile ────────────────────────────

class _BlockedPane extends StatelessWidget {
  const _BlockedPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: KoruColors.dangerContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.hourglass_empty,
            size: 40,
            color: KoruColors.onDangerContainer,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: KoruColors.textPrimary,
            fontSize: 16,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: KoruColors.primary,
            side: const BorderSide(color: KoruColors.outline),
          ),
          child: const Text('Riprova'),
        ),
      ],
    );
  }
}

// ─── Fase 2: memorizzazione ─────────────────────────────────────────────────

class _MemorizePane extends StatelessWidget {
  const _MemorizePane({required this.challenge, required this.countdown});

  final UnlockChallenge challenge;
  final AnimationController countdown;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 14,
          children: [
            for (var i = 0; i < challenge.sequence.length; i++)
              _SequenceCard(ordinal: i + 1, glyphId: challenge.sequence[i]),
          ],
        ),
        const SizedBox(height: 40),
        // La barra si SVUOTA: comunica "il tempo sta finendo" senza dover
        // leggere un numero, che in 3 secondi nessuno legge.
        AnimatedBuilder(
          animation: countdown,
          builder: (context, _) => ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: 1 - countdown.value,
              minHeight: 6,
              backgroundColor: KoruColors.surfaceContainer,
              valueColor: const AlwaysStoppedAnimation(KoruColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

/// Una casella della fase di memorizzazione: glifo grande + numero d'ordine.
/// Il numero è quello che rende "l'ordine" un dato esplicito da ricordare.
class _SequenceCard extends StatelessWidget {
  const _SequenceCard({required this.ordinal, required this.glyphId});

  final int ordinal;
  final String glyphId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 88,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: KoruColors.surfaceContainer,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: KoruColors.outline),
              ),
              child: Icon(
                glyphIcon(glyphId),
                size: 38,
                color: KoruColors.textPrimary,
              ),
            ),
          ),
          Positioned(
            top: 6,
            left: 8,
            child: Text(
              '$ordinal',
              style: const TextStyle(
                color: KoruColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Fase 3: ricostruzione ──────────────────────────────────────────────────

class _RecallPane extends StatelessWidget {
  const _RecallPane({
    required this.challenge,
    required this.progress,
    required this.showingError,
    required this.shake,
    required this.onTap,
  });

  final UnlockChallenge challenge;
  final int progress;
  final bool showingError;
  final AnimationController shake;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProgressDots(
          total: challenge.length,
          done: progress,
          error: showingError,
        ),
        const SizedBox(height: 28),
        AnimatedBuilder(
          animation: shake,
          builder: (context, child) {
            // Oscillazione smorzata: 3 andate/ritorni che si spengono.
            final t = shake.value;
            final dx = t == 0
                ? 0.0
                : math.sin(t * math.pi * 6) * 12 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: GridView.count(
            crossAxisCount: challenge.columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final glyphId in challenge.grid)
                _GlyphTile(
                  glyphId: glyphId,
                  error: showingError,
                  onTap: () => onTap(glyphId),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pallini di avanzamento: quanti glifi della sequenza sono già stati presi.
/// Non rivelano MAI quali — solo quanti.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.total,
    required this.done,
    required this.error,
  });

  final int total;
  final int done;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: i < done ? 26 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: error
                  ? KoruColors.danger
                  : i < done
                  ? KoruColors.primary
                  : KoruColors.surfaceElevated,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

class _GlyphTile extends StatelessWidget {
  const _GlyphTile({
    required this.glyphId,
    required this.error,
    required this.onTap,
  });

  final String glyphId;
  final bool error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: error ? KoruColors.dangerContainer : KoruColors.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Durante il feedback d'errore la griglia è inerte: onTap null toglie
        // anche il ripple, così non sembra che i tocchi contino ancora.
        onTap: error ? null : onTap,
        child: Icon(
          glyphIcon(glyphId),
          size: 34,
          color: error ? KoruColors.onDangerContainer : KoruColors.textPrimary,
        ),
      ),
    );
  }
}
