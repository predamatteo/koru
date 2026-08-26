import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';
import 'package:koru/domain/entities/statistics_period.dart';
import 'package:koru/presentation/providers/statistics_providers.dart';

import '../../_helpers/provider_test_utils.dart';

/// Helper: today's day-key matching StatisticsPeriod.currentRange formatting.
String _todayKey() => _dayKey(DateTime.now());

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  group('selectedPeriodProvider', () {
    test('defaults to today', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      expect(
        h.container.read(selectedPeriodProvider),
        StatisticsPeriod.today,
      );
    });

    test('can be set to week', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      h.container.read(selectedPeriodProvider.notifier).state =
          StatisticsPeriod.week;
      expect(
        h.container.read(selectedPeriodProvider),
        StatisticsPeriod.week,
      );
    });
  });

  /// Il ritorno a "oggi" ha tre pezzi di stato da azzerare insieme: se ne
  /// resta anche uno solo, la schermata si riapre su una finestra che l'utente
  /// non ha chiesto — ed è esattamente il bug per cui questa funzione esiste.
  group('resetStatsView', () {
    test('riporta periodo, giorno del grafico e navigazione a oggi', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      h.container.read(selectedPeriodProvider.notifier).state =
          StatisticsPeriod.week;
      h.container.read(selectedStatsDayProvider.notifier).state = 123456;
      h.container.read(selectedDayOffsetProvider.notifier).state = 4;

      resetStatsView(h.container.read);

      expect(h.container.read(selectedPeriodProvider), StatisticsPeriod.today);
      expect(h.container.read(selectedStatsDayProvider), isNull);
      expect(h.container.read(selectedDayOffsetProvider), 0);
    });

    test('su una vista già a oggi non cambia niente', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      resetStatsView(h.container.read);

      expect(h.container.read(selectedPeriodProvider), StatisticsPeriod.today);
      expect(h.container.read(selectedStatsDayProvider), isNull);
      expect(h.container.read(selectedDayOffsetProvider), 0);
    });
  });

  group('selectedDayOffsetProvider', () {
    test('parte da oggi', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      expect(h.container.read(selectedDayOffsetProvider), 0);
    });

    test('sposta anche i conteggi di blocco sul giorno navigato', () async {
      // Non basta che lo screen time segua la navigazione: se i blocchi
      // restassero fermi a oggi, la stessa schermata mostrerebbe due giorni
      // diversi nello stesso momento.
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final now = DateTime.now();
      final threeDaysAgo = DateTime(now.year, now.month, now.day - 3);
      await h.db.restrictedAccessEventsDao.insertEvent(
        RestrictedAccessEventsCompanion.insert(
          occurredAt: threeDaysAgo.millisecondsSinceEpoch,
          dayStartDate: _dayKey(threeDaysAgo),
          packageName: 'com.x',
          eventType: 0,
          restrictionType: 0,
        ),
      );

      expect(
        await h.container.read(blockTriggeredCountProvider.stream).first,
        0,
        reason: 'oggi non ha eventi',
      );

      h.container.read(selectedDayOffsetProvider.notifier).state = 3;
      expect(
        await h.container.read(blockTriggeredCountProvider.stream).first,
        1,
      );
    });
  });

  group('blockTriggeredCountProvider', () {
    test('emits 0 on empty db', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final v =
          await h.container.read(blockTriggeredCountProvider.stream).first;
      expect(v, 0);
    });

    test('counts events with eventType=0 in the selected period', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final today = _todayKey();
      final now = DateTime.now().millisecondsSinceEpoch;
      await h.db.restrictedAccessEventsDao.insertEvent(
        RestrictedAccessEventsCompanion.insert(
          occurredAt: now,
          dayStartDate: today,
          packageName: 'com.x',
          eventType: 0,
          restrictionType: 0,
        ),
      );
      await h.db.restrictedAccessEventsDao.insertEvent(
        RestrictedAccessEventsCompanion.insert(
          occurredAt: now,
          dayStartDate: today,
          packageName: 'com.x',
          eventType: 0,
          restrictionType: 0,
        ),
      );
      // Skipped (different eventType) — non deve essere contato.
      await h.db.restrictedAccessEventsDao.insertEvent(
        RestrictedAccessEventsCompanion.insert(
          occurredAt: now,
          dayStartDate: today,
          packageName: 'com.x',
          eventType: 1,
          restrictionType: 0,
        ),
      );

      final v =
          await h.container.read(blockTriggeredCountProvider.stream).first;
      expect(v, 2);
    });
  });

  group('blocksTodayCountProvider', () {
    test('conta gli eventi di blocco di oggi', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final now = DateTime.now().millisecondsSinceEpoch;
      await h.db.restrictedAccessEventsDao.insertEvent(
        RestrictedAccessEventsCompanion.insert(
          occurredAt: now,
          dayStartDate: _todayKey(),
          packageName: 'com.x',
          eventType: 0,
          restrictionType: 0,
        ),
      );

      final v = await h.container.read(blocksTodayCountProvider.stream).first;
      expect(v, 1);
    });

    test('ignora il periodo selezionato nella schermata Statistiche',
        () async {
      // È l'unico posto in cui questa invariante può essere difesa: la
      // dashboard mostrava i blocchi della SETTIMANA sotto l'etichetta
      // "Blocks" se l'utente aveva lasciato /stats su "This week", perché
      // condivideva il provider con lo switcher di periodo.
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final now = DateTime.now();
      // Evento di 3 giorni fa: dentro la finestra "settimana", fuori da "oggi".
      final threeDaysAgo = DateTime(now.year, now.month, now.day - 3);
      await h.db.restrictedAccessEventsDao.insertEvent(
        RestrictedAccessEventsCompanion.insert(
          occurredAt: threeDaysAgo.millisecondsSinceEpoch,
          dayStartDate: '${threeDaysAgo.year.toString().padLeft(4, '0')}-'
              '${threeDaysAgo.month.toString().padLeft(2, '0')}-'
              '${threeDaysAgo.day.toString().padLeft(2, '0')}',
          packageName: 'com.x',
          eventType: 0,
          restrictionType: 0,
        ),
      );

      h.container.read(selectedPeriodProvider.notifier).state =
          StatisticsPeriod.week;

      // Il provider della schermata Statistiche lo vede...
      expect(
        await h.container.read(blockTriggeredCountProvider.stream).first,
        1,
      );
      // ...quello della dashboard no: la sua finestra resta oggi.
      expect(
        await h.container.read(blocksTodayCountProvider.stream).first,
        0,
      );
    });
  });

  group('blockSkippedCountProvider', () {
    test('counts events with eventType=1', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final today = _todayKey();
      final now = DateTime.now().millisecondsSinceEpoch;
      await h.db.restrictedAccessEventsDao.insertEvent(
        RestrictedAccessEventsCompanion.insert(
          occurredAt: now,
          dayStartDate: today,
          packageName: 'com.x',
          eventType: 1,
          restrictionType: 0,
        ),
      );

      final v = await h.container.read(blockSkippedCountProvider.stream).first;
      expect(v, 1);
    });
  });

  group('perAppBreakdownProvider', () {
    test('returns per-app+per-eventType aggregated counts', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final today = _todayKey();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < 3; i++) {
        await h.db.restrictedAccessEventsDao.insertEvent(
          RestrictedAccessEventsCompanion.insert(
            occurredAt: now,
            dayStartDate: today,
            packageName: 'com.a',
            eventType: 0,
            restrictionType: 0,
          ),
        );
      }
      await h.db.restrictedAccessEventsDao.insertEvent(
        RestrictedAccessEventsCompanion.insert(
          occurredAt: now,
          dayStartDate: today,
          packageName: 'com.b',
          eventType: 0,
          restrictionType: 0,
        ),
      );

      final rows =
          await h.container.read(perAppBreakdownProvider.stream).first;
      expect(rows, hasLength(2));
      // Ordinato desc per cnt → com.a (3) prima.
      expect(rows.first.packageName, 'com.a');
      expect(rows.first.count, 3);
      expect(rows.last.packageName, 'com.b');
      expect(rows.last.count, 1);
    });
  });

  group('topIntentionsProvider', () {
    test('returns intention titles sorted by usage count desc', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      final today = _todayKey();
      final now = DateTime.now().millisecondsSinceEpoch;
      // 3x "check_messages", 1x "post"
      for (var i = 0; i < 3; i++) {
        await h.db.intentionUsageEventsDao.insertEvent(
          IntentionUsageEventsCompanion.insert(
            occurredAt: now,
            dayStartDate: today,
            packageName: 'com.x',
            intentionName: 'check_messages',
          ),
        );
      }
      await h.db.intentionUsageEventsDao.insertEvent(
        IntentionUsageEventsCompanion.insert(
          occurredAt: now,
          dayStartDate: today,
          packageName: 'com.x',
          intentionName: 'post',
        ),
      );

      final rows = await h.container.read(topIntentionsProvider.stream).first;
      expect(rows, hasLength(2));
      expect(rows.first.title, 'check_messages');
      expect(rows.first.usageCount, 3);
      expect(rows.last.title, 'post');
      expect(rows.last.usageCount, 1);
    });
  });
}
