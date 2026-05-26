import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/day_flags.dart';
import 'package:koru/core/constants/profile_types.dart';
import 'package:koru/data/database/app_database.dart';
import 'package:koru/data/models/profile_model.dart';
import 'package:koru/presentation/providers/active_profile_provider.dart';
import 'package:koru/presentation/providers/profile_providers.dart';

import '../../_helpers/provider_test_utils.dart';

/// Costruisce un [Profile] data class direttamente — bypassa la repo per
/// poter controllare a piacere isEnabled / pausedUntil / dayFlags /
/// typeCombinations dentro i test.
Profile _profile({
  required int id,
  required String title,
  bool isEnabled = true,
  int pausedUntil = 0,
  int dayFlags = DayFlags.allDays,
  int typeCombinations = 0,
  int onUntil = 0,
}) {
  return Profile(
    id: id,
    title: title,
    typeCombinations: typeCombinations,
    onConditions: 0,
    operator: 0,
    dayFlags: dayFlags,
    blockNotifications: true,
    blockLaunch: true,
    addNewApplications: false,
    isEnabled: isEnabled,
    isLocked: false,
    lastStartTime: 0,
    onUntil: onUntil,
    lockedUntil: 0,
    lockAt: 0,
    pausedUntil: pausedUntil,
    blockingMode: 0,
    emoji: 'NoIcon',
    blockUnsupportedBrowsers: false,
    blockAdultContent: false,
    sortOrder: 0,
    colorHex: '#000000',
    presetId: null,
  );
}

Interval _interval({
  required int id,
  required int profileId,
  required int from,
  required int to,
}) {
  return Interval(
    id: id,
    profileId: profileId,
    fromMinutes: from,
    toMinutes: to,
    parentId: null,
    isAllDayAuto: false,
    isEnabled: true,
  );
}

/// Setup tipico:
/// 1. Override profilesProvider con Stream.value(list).
/// 2. Forza prima la risoluzione di profilesProvider per evitare l'emissione
///    "AsyncLoading" iniziale che farebbe yieldare lista vuota.
/// 3. Legge l'output di activeProfilesProvider come `.first`.
Future<List<ProfileModel>> _readActive(
  TestHarness h,
) async {
  // Garantisce che profilesProvider sia AsyncData prima di consumare
  // activeProfilesProvider.stream.
  await h.container.read(profilesProvider.future);
  return h.container.read(activeProfilesProvider.stream).first;
}

TestHarness _harnessWith(List<ProfileModel> profiles) {
  return buildTestContainer(extra: [
    profilesProvider.overrideWith((ref) => Stream.value(profiles)),
  ]);
}

void main() {
  group('activeProfilesProvider', () {
    test('emits empty list when there are no profiles', () async {
      final h = _harnessWith(const []);
      addTearDown(h.dispose);

      final list = await _readActive(h);
      expect(list, isEmpty);
    });

    test('filters out profiles where isEnabled=false', () async {
      final p = ProfileModel(
        data: _profile(id: 1, title: 'Off', isEnabled: false),
      );
      final h = _harnessWith([p]);
      addTearDown(h.dispose);

      final list = await _readActive(h);
      expect(list, isEmpty);
    });

    test('filters out profiles with pausedUntil < 0 (disabled by user)',
        () async {
      final p = ProfileModel(
        data: _profile(id: 2, title: 'Paused', pausedUntil: -1),
      );
      final h = _harnessWith([p]);
      addTearDown(h.dispose);

      final list = await _readActive(h);
      expect(list, isEmpty);
    });

    test('filters out profiles paused into the future', () async {
      final future =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
      final p = ProfileModel(
        data: _profile(id: 3, title: 'Snoozed', pausedUntil: future),
      );
      final h = _harnessWith([p]);
      addTearDown(h.dispose);

      final list = await _readActive(h);
      expect(list, isEmpty);
    });

    test('keeps profiles paused in the past (snooze finished)', () async {
      final past = DateTime.now()
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      final p = ProfileModel(
        data: _profile(id: 4, title: 'PastPause', pausedUntil: past),
      );
      final h = _harnessWith([p]);
      addTearDown(h.dispose);

      final list = await _readActive(h);
      expect(list, hasLength(1));
      expect(list.single.title, 'PastPause');
    });

    test('filters out profiles whose dayFlags do not include today',
        () async {
      // dayFlags = 0 → never active any day.
      final p = ProfileModel(
        data: _profile(id: 5, title: 'NoDays', dayFlags: 0),
      );
      final h = _harnessWith([p]);
      addTearDown(h.dispose);

      final list = await _readActive(h);
      expect(list, isEmpty);
    });

    test('filters out time-typed profiles when no interval matches now',
        () async {
      // Finestra deterministica che ESCLUDE l'istante corrente:
      // [now+30min, now+60min). `now` (= now+0) non vi cade mai, anche se la
      // finestra wrappa oltre la mezzanotte (in quel caso resta comunque dopo
      // now). NB: non si può usare più (0,0) come "mai" — da CR-06 from==to
      // significa 24h (vedi test dedicato sotto).
      final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
      final from = (nowMin + 30) % 1440;
      final to = (nowMin + 60) % 1440;
      final p = ProfileModel(
        data: _profile(
          id: 6,
          title: 'Time',
          typeCombinations: ProfileType.time,
        ),
        intervals: [_interval(id: 1, profileId: 6, from: from, to: to)],
      );
      final h = _harnessWith([p]);
      addTearDown(h.dispose);

      final list = await _readActive(h);
      expect(list, isEmpty);
    });

    test('keeps time-typed profiles with a from==to (24h) interval', () async {
      // CR-06: from==to ⇒ intervallo a giornata intera. Prima questo profilo
      // veniva filtrato (il vecchio isNowInRange tornava "mai" su from==to),
      // divergendo dall'enforcement nativo. Ora è attivo a qualunque ora.
      final p = ProfileModel(
        data: _profile(
          id: 60,
          title: 'TwentyFour',
          typeCombinations: ProfileType.time,
        ),
        intervals: [_interval(id: 1, profileId: 60, from: 600, to: 600)],
      );
      final h = _harnessWith([p]);
      addTearDown(h.dispose);

      final list = await _readActive(h);
      expect(list.map((p) => p.title), ['TwentyFour']);
    });

    test('filters out time-typed profiles whose only matching interval is disabled',
        () async {
      // refinement #2 (CR-06): un intervallo disabilitato non conta — come la
      // query nativa `AND is_enabled = 1`. Qui l'unico intervallo è 24h
      // (matcherebbe) ma DISABILITATO → resta solo l'insieme vuoto di
      // intervalli abilitati ⇒ nessun gating ⇒ profilo KEPT. Verifichiamo che
      // l'intervallo disabilitato sia stato ignorato (non blocca, ma neanche
      // "matcha"): il profilo passa per assenza di intervalli abilitati.
      final disabled = Interval(
        id: 1,
        profileId: 61,
        fromMinutes: 600,
        toMinutes: 600,
        parentId: null,
        isAllDayAuto: false,
        isEnabled: false,
      );
      final p = ProfileModel(
        data: _profile(
          id: 61,
          title: 'DisabledIv',
          typeCombinations: ProfileType.time,
        ),
        intervals: [disabled],
      );
      final h = _harnessWith([p]);
      addTearDown(h.dispose);

      final list = await _readActive(h);
      expect(list.map((p) => p.title), ['DisabledIv']);
    });

    test('keeps time-typed profiles with full-day interval (0..1440)',
        () async {
      final p = ProfileModel(
        data: _profile(
          id: 7,
          title: 'AllDay',
          typeCombinations: ProfileType.time,
        ),
        intervals: [_interval(id: 1, profileId: 7, from: 0, to: 1440)],
      );
      final h = _harnessWith([p]);
      addTearDown(h.dispose);

      final list = await _readActive(h);
      expect(list, hasLength(1));
      expect(list.single.title, 'AllDay');
    });

    test('time-typed profiles with no intervals are NOT filtered',
        () async {
      // Il check di intervals è gated da p.intervals.isNotEmpty.
      final p = ProfileModel(
        data: _profile(
          id: 8,
          title: 'TimeNoIntervals',
          typeCombinations: ProfileType.time,
        ),
      );
      final h = _harnessWith([p]);
      addTearDown(h.dispose);

      final list = await _readActive(h);
      expect(list.map((p) => p.title), ['TimeNoIntervals']);
    });

    test('filters out profiles with expired onUntil', () async {
      final past = DateTime.now()
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      final p = ProfileModel(
        data: _profile(
          id: 9,
          title: 'Expired',
          onUntil: past,
        ),
      );
      final h = _harnessWith([p]);
      addTearDown(h.dispose);

      final list = await _readActive(h);
      expect(list, isEmpty);
    });

    test('keeps profiles with onUntil in the future', () async {
      final future =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
      final p = ProfileModel(
        data: _profile(
          id: 10,
          title: 'Future',
          onUntil: future,
        ),
      );
      final h = _harnessWith([p]);
      addTearDown(h.dispose);

      final list = await _readActive(h);
      expect(list.map((p) => p.title), ['Future']);
    });

    test('returns multiple active profiles when several match', () async {
      final a = ProfileModel(data: _profile(id: 11, title: 'A'));
      final b = ProfileModel(data: _profile(id: 12, title: 'B'));
      final h = _harnessWith([a, b]);
      addTearDown(h.dispose);

      final list = await _readActive(h);
      expect(list.map((p) => p.title), ['A', 'B']);
    });
  });
}
