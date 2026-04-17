import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';

void main() {
  group('AppDatabase smoke', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('seeds default blocking config on create', () async {
      final rows = await db.select(db.blockingConfigs).get();
      expect(rows, hasLength(1));
      expect(rows.first.id, 'default');
    });

    test('profile CRUD', () async {
      final id = await db.insertProfile(
        ProfilesCompanion.insert(
          title: const Value('Mindful Morning'),
          isEnabled: const Value(true),
        ),
      );
      final fetched = await db.getProfileById(id);
      expect(fetched, isNotNull);
      expect(fetched!.title, 'Mindful Morning');
      expect(fetched.colorHex, '#5C8262');

      await db.updateProfile(
        ProfilesCompanion(
          id: Value(id),
          title: const Value('Morning v2'),
          colorHex: const Value('#8A6D52'),
        ),
      );
      final after = await db.getProfileById(id);
      expect(after!.title, 'Morning v2');
      expect(after.colorHex, '#8A6D52');

      await db.deleteProfile(id);
      expect(await db.getProfileById(id), isNull);
    });

    test('favorites reorder preserves indices', () async {
      await db
          .into(db.applications)
          .insert(ApplicationsCompanion.insert(
            packageName: 'com.a',
            label: 'A',
            labelForSearch: 'a',
          ));
      await db
          .into(db.applications)
          .insert(ApplicationsCompanion.insert(
            packageName: 'com.b',
            label: 'B',
            labelForSearch: 'b',
          ));
      await db
          .into(db.applications)
          .insert(ApplicationsCompanion.insert(
            packageName: 'com.c',
            label: 'C',
            labelForSearch: 'c',
          ));

      await db.addFavorite('com.a');
      await db.addFavorite('com.b');
      await db.addFavorite('com.c');

      var favs = await db.getFavorites();
      expect(favs.map((f) => f.packageName).toList(), ['com.a', 'com.b', 'com.c']);

      await db.reorderFavorites(['com.c', 'com.a', 'com.b']);
      favs = await db.getFavorites();
      expect(favs.map((f) => f.packageName).toList(), ['com.c', 'com.a', 'com.b']);
    });

    test('analytics DAO roundtrip', () async {
      await db.restrictedAccessEventsDao.insertEvent(
        RestrictedAccessEventsCompanion.insert(
          occurredAt: DateTime.now().millisecondsSinceEpoch,
          dayStartDate: '2026-04-17',
          packageName: 'com.instagram.android',
          eventType: 0,
          restrictionType: 1,
        ),
      );
      final count = await db.restrictedAccessEventsDao
          .countEventsByTypeInRange(0, '2026-04-17', '2026-04-17');
      expect(count, 1);
    });
  });
}
