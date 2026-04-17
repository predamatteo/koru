enum StatisticsPeriod {
  today('Today', 1),
  week('This week', 7),
  month('This month', 30);

  const StatisticsPeriod(this.label, this.daysBack);

  final String label;
  final int daysBack;

  ({String from, String to}) currentRange({DateTime? now}) {
    final today = now ?? DateTime.now();
    final from = today.subtract(Duration(days: daysBack - 1));
    return (from: _fmt(from), to: _fmt(today));
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
