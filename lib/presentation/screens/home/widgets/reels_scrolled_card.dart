import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../platform/blocking_channel.dart';
import '../../../providers/reel_counts_provider.dart';

/// Card "reel scrollati oggi": totale grande, ripartizione per sorgente e
/// confronto con la media dei giorni precedenti.
///
/// ## Perché sparisce a zero
/// La card non si mostra finché non c'è almeno un reel. Un "0" permanente in
/// cima alla dashboard sarebbe rumore per chi non usa Reels o Shorts, e
/// soprattutto sarebbe indistinguibile dal caso in cui la detection si è rotta
/// dopo un aggiornamento di Instagram — cioè trasformerebbe un guasto in un
/// complimento. Stessa scelta della pill sul widget e di [TodayLimitsCard], che
/// si nasconde senza limiti impostati.
///
/// ## Cosa NON dice
/// Nessun giudizio, nessuna soglia rossa: il numero è il messaggio. È lo stesso
/// registro del resto della dashboard, e un conteggio inferito da eventi di
/// accessibilità non ha la precisione per sostenere un allarme.
class ReelsScrolledCard extends ConsumerWidget {
  const ReelsScrolledCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Spenta la feature, sparisce la card: chi non vuole essere contato non
    // deve trovarsi un promemoria della cosa in cima alla dashboard.
    // `?? true` come l'interruttore in Impostazioni — il default nativo è
    // acceso, e far lampeggiare la card ad ogni resume sarebbe peggio.
    final enabled = ref.watch(reelCounterEnabledProvider).valueOrNull ?? true;
    if (!enabled) return const SizedBox.shrink();

    // `valueOrNull` e non uno spinner: la card compare quando il dato c'è,
    // senza far saltare il layout della dashboard a ogni resume (stessa
    // postura degli altri contatori della home).
    //
    // A zero la card RESTA. Nasconderla era la scelta di partenza ("uno 0
    // fisso non dice niente"), ma rende la feature indistinguibile da una
    // rotta: il primo giorno non vedi nulla e non hai modo di sapere se stia
    // contando. E in un'app che misura quanto scrolli, "oggi nessuno" non è
    // un vuoto — è il risultato migliore possibile.
    final counts = ref.watch(reelCountsTodayProvider).valueOrNull;
    if (counts == null) return const SizedBox.shrink();

    final average = ref.watch(reelWeeklyAverageProvider);
    final sources = ReelSource.values
        .where((s) => counts.forSource(s) > 0)
        .toList(growable: false);

    return Container(
      // Il margine inferiore appartiene alla card e non alla lista che la
      // ospita: la home la include incondizionatamente, quindi uno spaziatore
      // esterno resterebbe anche nei (molti) giorni in cui la card non c'è,
      // lasciando un vuoto doppio fra le due card vicine.
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: KoruColors.surfaceContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.swipe_vertical_outlined,
                size: 18,
                color: KoruColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'SCROLLED TODAY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: KoruColors.textSecondary,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${counts.total}',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  height: 1,
                  color: KoruColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                counts.total == 1 ? 'reel' : 'reels',
                style: const TextStyle(
                  fontSize: 15,
                  color: KoruColors.textSecondary,
                ),
              ),
            ],
          ),
          // A zero il confronto con la media cede il posto a una riga esplicita:
          // senza, la card mostrerebbe un "0" nudo e sembrerebbe in caricamento.
          if (counts.total == 0) ...[
            const SizedBox(height: 6),
            Text(
              average != null && average > 0
                  ? 'None today — your average is $average'
                  : 'None today',
              style: const TextStyle(
                fontSize: 13,
                color: KoruColors.textSecondary,
              ),
            ),
          ] else if (average != null) ...[
            const SizedBox(height: 6),
            Text(
              _comparisonLabel(counts.total, average),
              style: const TextStyle(
                fontSize: 13,
                color: KoruColors.textSecondary,
              ),
            ),
          ],
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final source in sources)
              _SourceRow(
                label: source.label,
                count: counts.forSource(source),
                total: counts.total,
              ),
          ],
        ],
      ),
    );
  }

  /// Confronto con la media dei giorni precedenti (oggi escluso: è parziale).
  ///
  /// Il caso "uguale" esiste apposta — arrotondare tutto a "sopra" o "sotto"
  /// darebbe un verdetto anche quando la differenza è un reel.
  String _comparisonLabel(int today, int average) {
    if (average <= 0) return 'First days of tracking';
    final delta = today - average;
    if (delta == 0) return 'Right on your daily average ($average)';
    final direction = delta > 0 ? 'more' : 'fewer';
    return '${delta.abs()} $direction than your daily average ($average)';
  }
}

/// Riga per sorgente: etichetta, barra proporzionale, conteggio.
///
/// La barra è relativa al TOTALE di oggi, non a un massimo storico: dice "quanto
/// di oggi viene da qui", che è l'unica domanda a cui questa card può rispondere
/// onestamente senza una baseline.
class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.label,
    required this.count,
    required this.total,
  });

  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: KoruColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: KoruColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: KoruColors.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(
                KoruColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
