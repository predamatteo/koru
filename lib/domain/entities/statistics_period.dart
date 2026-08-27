enum StatisticsPeriod {
  today(1),
  week(7);

  const StatisticsPeriod(this.daysBack);

  final int daysBack;

  // L'etichetta mostrata nel selettore è testo tradotto e non sta qui: questo
  // file è `domain/` e non importa Flutter. Vedi `StatisticsPeriodL10n.label`
  // in `presentation/l10n/model_labels.dart`.

  /// Quanti giorni si può tornare indietro con la navigazione delle
  /// Statistiche.
  ///
  /// Non è un numero estetico: `UsageStatsManager` conserva ~7-10 giorni di
  /// eventi, quindi oltre questa soglia lo screen-time comincerebbe a tornare
  /// zero — e uno zero indistinguibile da "quel giorno non hai usato niente"
  /// è peggio che non offrire il giorno. Sei giorni indietro sono anche
  /// esattamente la finestra che il grafico settimanale già mostra.
  static const int maxDaysBack = 6;

  /// Finestra del periodo come coppia di date `YYYY-MM-DD`, **inclusiva** su
  /// entrambi gli estremi (è la forma che vogliono le query Drift).
  ///
  /// [shiftDays] sposta l'intera finestra indietro di altrettanti giorni:
  /// `0` = periodo corrente, `1` = il giorno (o la settimana) precedente…
  ///
  /// I giorni si calcolano con `DateTime(y, m, d - n)` e non con
  /// `subtract(Duration(days: n))`: il secondo somma 24 ore vere e a cavallo
  /// di un cambio di ora legale finisce sul giorno sbagliato.
  ({String from, String to}) currentRange({DateTime? now, int shiftDays = 0}) {
    final ref = now ?? DateTime.now();
    final anchor = DateTime(ref.year, ref.month, ref.day - shiftDays);
    final from = DateTime(
      anchor.year,
      anchor.month,
      anchor.day - (daysBack - 1),
    );
    return (from: _fmt(from), to: _fmt(anchor));
  }

  /// Range in ms per le API che vogliono timestamp
  /// (`UsageStatsManager.queryUsageStats`).
  ///
  /// Con [shiftDays] a zero il `to` è **adesso** — il periodo corrente è in
  /// corso e includere il futuro non aggiungerebbe nulla. Su un periodo
  /// passato invece il `to` è la mezzanotte successiva alla fine della
  /// finestra: quel giorno è chiuso e va contato per intero, altrimenti
  /// "ieri" mostrerebbe solo le ore fino a quest'ora di ieri.
  ({int from, int to}) currentRangeMs({DateTime? now, int shiftDays = 0}) {
    final ref = now ?? DateTime.now();
    final anchor = DateTime(ref.year, ref.month, ref.day - shiftDays);
    final from = DateTime(
      anchor.year,
      anchor.month,
      anchor.day - (daysBack - 1),
    );
    final to = shiftDays == 0
        ? ref
        : DateTime(anchor.year, anchor.month, anchor.day + 1);
    return (from: from.millisecondsSinceEpoch, to: to.millisecondsSinceEpoch);
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
