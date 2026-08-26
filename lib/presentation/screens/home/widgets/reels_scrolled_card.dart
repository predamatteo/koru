import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../platform/blocking_channel.dart';
import '../../../providers/reel_counts_provider.dart';

/// Card "reel scrollati oggi": totale grande, ripartizione per sorgente e
/// confronto con la media dei giorni precedenti.
///
/// ## Perché c'è SEMPRE
/// La card è un elemento fisso della dashboard: non sparisce a zero e non ha
/// un interruttore che la spenga (il contatore è sempre attivo). Nasconderla
/// quando non c'è niente da mostrare rendeva la feature indistinguibile da una
/// rotta — il primo giorno non vedevi nulla e non avevi modo di sapere se
/// stesse contando, e un aggiornamento di Instagram che spacca la detection
/// diventava silenziosamente un complimento. Un posto fisso in dashboard è
/// anche il modo più economico per accorgersi che si è rotta: se resta a zero
/// per giorni in cui hai scrollato, il colpevole è nei view-id (vedi
/// `REELS_PAGER` / `SHORTS_PAGER` in `res/raw/*_view_ids.json`).
///
/// ## Cosa NON dice
/// Nessun giudizio, nessuna soglia rossa: il numero è il messaggio. È lo stesso
/// registro del resto della dashboard, e un conteggio inferito da eventi di
/// accessibilità non ha la precisione per sostenere un allarme.
class ReelsScrolledCard extends ConsumerWidget {
  const ReelsScrolledCard({
    super.key,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  /// Margine esterno della card. Il default porta con sé lo spazio verso la
  /// card successiva (vedi la nota sulla scocca sotto); va azzerato quando la
  /// card sta dentro una Row affiancata a un'altra tessera, altrimenti i due
  /// fondi non si allineano.
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `valueOrNull` con fallback a vuoto e non uno spinner: la card occupa
    // sempre lo stesso posto e il numero si riempie quando il dato arriva,
    // senza far saltare il layout della dashboard a ogni resume (stessa
    // postura degli altri contatori della home). Al primissimo frame mostra
    // "0 reels / None today", che è anche la verità più probabile.
    final counts =
        ref.watch(reelCountsTodayProvider).valueOrNull ?? ReelCounts.empty;

    final average = ref.watch(reelWeeklyAverageProvider);
    final sources = ReelSource.values
        .where((s) => counts.forSource(s) > 0)
        .toList(growable: false);

    return Container(
      // Il margine inferiore appartiene alla card e non alla lista che la
      // ospita, per non dover riaggiustare gli spaziatori della home ogni
      // volta che l'ordine delle card cambia.
      margin: margin,
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
