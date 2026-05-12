import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/database/app_database.dart';
import 'package:koru/data/repositories/achievements_repository.dart';

void main() {
  group('AchievementsRepository', () {
    late AppDatabase db;
    late AchievementsRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AchievementsRepository(db.achievementsDao);
    });

    tearDown(() async {
      await db.close();
    });

    group('getUnlockedIds', () {
      test('returns an empty set on a fresh database', () async {
        final ids = await repo.getUnlockedIds();
        expect(ids, isEmpty);
        expect(ids, isA<Set<String>>());
      });

      test('returns every distinct unlocked id', () async {
        await repo.unlock('a');
        await repo.unlock('b');
        await repo.unlock('c');

        final ids = await repo.getUnlockedIds();
        expect(ids, {'a', 'b', 'c'});
      });
    });

    group('isUnlocked', () {
      test('false when nothing has been unlocked', () async {
        expect(await repo.isUnlocked('focus_first'), isFalse);
      });

      test('true after unlock', () async {
        await repo.unlock('focus_first');
        expect(await repo.isUnlocked('focus_first'), isTrue);
      });

      test('only true for the specific id', () async {
        await repo.unlock('focus_first');
        expect(await repo.isUnlocked('monk_mode'), isFalse);
      });
    });

    group('unlock', () {
      test('returns true the first time and persists the row', () async {
        final unlocked = await repo.unlock('focus_first');
        expect(unlocked, isTrue);

        final ids = await repo.getUnlockedIds();
        expect(ids, contains('focus_first'));
      });

      test('returns false on the second call for the same id (idempotency)',
          () async {
        expect(await repo.unlock('focus_first'), isTrue);
        expect(await repo.unlock('focus_first'), isFalse);
        expect(await repo.unlock('focus_first'), isFalse);

        // No duplicates persisted.
        final ids = await repo.getUnlockedIds();
        expect(ids.where((id) => id == 'focus_first'), hasLength(1));
      });

      test('distinct ids can be unlocked independently', () async {
        expect(await repo.unlock('a'), isTrue);
        expect(await repo.unlock('b'), isTrue);
        expect(await repo.unlock('a'), isFalse);
        expect(await repo.unlock('b'), isFalse);

        expect(await repo.getUnlockedIds(), {'a', 'b'});
      });
    });

    group('watchAll', () {
      test('initial emission is an empty list', () async {
        await expectLater(repo.watchAll(), emits(isEmpty));
      });

      test('emits the new list after an unlock', () async {
        final emissions = <List<AchievementsUnlockedData>>[];
        final sub = repo.watchAll().listen(emissions.add);

        await repo.unlock('focus_first');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();

        expect(emissions.first, isEmpty);
        expect(emissions.last.map((r) => r.id), contains('focus_first'));
      });
    });
  });
}
