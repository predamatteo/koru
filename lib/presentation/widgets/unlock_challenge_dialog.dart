import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/koru_colors.dart';
import '../../domain/entities/unlock_challenge.dart';
import '../providers/unlock_challenge_provider.dart';
import 'unlock_challenge_glyphs.dart';

/// Gate di attrito da mettere davanti a **ogni** azione che indebolisce una
/// protezione (spegnere un profilo, cancellarlo, togliergli app bloccate).
///
/// Ritorna `true` se si può procedere: o perché la sfida è disattivata
/// ([UnlockChallengeLevel.off], comportamento storico) o perché l'utente l'ha
/// superata. Ritorna `false` se ha annullato — e annullare è la direzione
/// SICURA (la protezione resta attiva), quindi è volutamente facile: back,
/// tocco fuori… no, il barrier è bloccato, ma il pulsante "Lascia stare" è
/// sempre lì. Non serve intrappolare nessuno: chi vuole davvero uscire fa il
/// puzzle, chi stava solo cedendo all'impulso ha già ottenuto la sua pausa.
///
/// [action] completa la frase "Per `<action>` devi prima ricostruire una
/// sequenza di simboli", es. `'spegnere «Sera senza social»'`.
Future<bool> requireUnlockChallenge(
  BuildContext context,
  WidgetRef ref, {
  required String action,
}) async {
  final level = ref.read(unlockChallengeLevelProvider);
  if (!level.isActive) return true;

  final passed = await showDialog<bool>(
    context: context,
    // Niente dismiss dal barrier: uscire deve essere una scelta esplicita
    // (il pulsante), non un tocco distratto a lato.
    barrierDismissible: false,
    builder: (_) => UnlockChallengeDialog(level: level, action: action),
  );
  return passed ?? false;
}

enum _Phase { intro, memorize, recall }

class UnlockChallengeDialog extends StatefulWidget {
  const UnlockChallengeDialog({
    super.key,
    required this.level,
    required this.action,
  });

  final UnlockChallengeLevel level;
  final String action;

  @override
  State<UnlockChallengeDialog> createState() => _UnlockChallengeDialogState();
}

class _UnlockChallengeDialogState extends State<UnlockChallengeDialog>
    with TickerProviderStateMixin {
  late UnlockChallenge _challenge;
  _Phase _phase = _Phase.intro;

  /// Quanti glifi della sequenza sono già stati indovinati in questo tentativo.
  int _progress = 0;

  /// Tentativi falliti. Mostrato all'utente: vedere il contatore salire è parte
  /// dell'attrito (rende visibile "quanto la stai volendo").
  int _failedAttempts = 0;

  /// True nella finestra di feedback dopo un tocco sbagliato: la griglia è
  /// congelata (niente tocchi) mentre l'animazione di errore gira.
  bool _showingError = false;

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
    _challenge = generateUnlockChallenge(widget.level);
    _countdown = AnimationController(
      vsync: this,
      duration: widget.level.memorizeDuration,
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
    setState(() => _phase = _Phase.recall);
  }

  /// (Ri)genera una sfida NUOVA e riparte dalla memorizzazione.
  ///
  /// Rigenerare invece di ripresentare la stessa sequenza è deliberato: se
  /// dopo un errore rivedessi lo stesso puzzle, al terzo tentativo lo
  /// risolveresti a memoria muscolare e l'attrito evaporerebbe.
  void _startMemorizePhase() {
    setState(() {
      _challenge = generateUnlockChallenge(widget.level);
      _progress = 0;
      _showingError = false;
      _phase = _Phase.memorize;
    });
    _countdown.forward(from: 0);
  }

  /// Sincrono di proposito. Le vibrazioni sono fire-and-forget
  /// (`.ignore()`): aspettarle metterebbe un round-trip di platform channel
  /// sul percorso critico di OGNI tocco, e un device che non risponde
  /// congelerebbe la griglia proprio mentre l'utente la sta usando.
  void _onGlyphTap(String glyphId) {
    if (_showingError) return;

    if (_challenge.isCorrectNext(_progress, glyphId)) {
      HapticFeedback.selectionClick().ignore();
      final next = _progress + 1;
      if (next < _challenge.length) {
        setState(() => _progress = next);
        return;
      }
      // Sequenza completa: sblocca.
      HapticFeedback.mediumImpact().ignore();
      Navigator.of(context).pop(true);
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

  Future<void> _playErrorFeedback() async {
    await _shake.forward(from: 0);
    if (!mounted) return;
    // Pausa di lettura: senza, la griglia si rigenererebbe nello stesso
    // istante in cui finisce lo shake e sembrerebbe un glitch invece di un
    // "no, ricomincia".
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    _startMemorizePhase();
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
                  child: SingleChildScrollView(
                    child: switch (_phase) {
                      _Phase.intro => _IntroPane(
                        level: widget.level,
                        action: widget.action,
                        onStart: _startMemorizePhase,
                      ),
                      _Phase.memorize => _MemorizePane(
                        challenge: _challenge,
                        countdown: _countdown,
                      ),
                      _Phase.recall => _RecallPane(
                        challenge: _challenge,
                        progress: _progress,
                        showingError: _showingError,
                        shake: _shake,
                        onTap: _onGlyphTap,
                      ),
                    },
                  ),
                ),
              ),
              if (_failedAttempts > 0)
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

  Widget _header(BuildContext context) {
    final (title, subtitle) = switch (_phase) {
      _Phase.intro => ('Un momento', 'Prima di indebolire la protezione.'),
      _Phase.memorize => (
        'Memorizza',
        'Questi simboli, in questo ordine. Poi spariscono.',
      ),
      _Phase.recall => (
        'Ricostruisci',
        'Toccali nell\'ordine di prima. Attenzione ai sosia.',
      ),
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
    );
  }
}

// ─── Fase 1: intro ──────────────────────────────────────────────────────────

class _IntroPane extends StatelessWidget {
  const _IntroPane({
    required this.level,
    required this.action,
    required this.onStart,
  });

  final UnlockChallengeLevel level;
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
        Text(
          '${level.sequenceLength} simboli, '
          '${level.memorizeDuration.inSeconds} secondi per guardarli, '
          'poi li ritrovi in una griglia piena di simboli quasi identici.',
          textAlign: TextAlign.center,
          style: const TextStyle(
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
