import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/profile_types.dart';

void main() {
  group('ProfileType constants', () {
    test('individual type bits are the documented powers of two', () {
      expect(ProfileType.time, 1);
      expect(ProfileType.location, 2);
      expect(ProfileType.wifi, 4);
      expect(ProfileType.bluetooth, 8);
      expect(ProfileType.usageLimit, 16);
      expect(ProfileType.launchCount, 32);
      expect(ProfileType.quickBlock, 64);
    });

    test('strictMode is the high bit (0x80000000)', () {
      expect(ProfileType.strictMode, 0x80000000);
    });

    test('all "phase 1/2" bits below strictMode are pairwise distinct', () {
      final bits = <int>{
        ProfileType.time,
        ProfileType.location,
        ProfileType.wifi,
        ProfileType.bluetooth,
        ProfileType.usageLimit,
        ProfileType.launchCount,
        ProfileType.quickBlock,
      };
      expect(bits.length, 7);
    });
  });

  group('ProfileType.hasType', () {
    test('returns true when the bit is set', () {
      final combinations = ProfileType.time | ProfileType.usageLimit;
      expect(ProfileType.hasType(combinations, ProfileType.time), isTrue);
      expect(ProfileType.hasType(combinations, ProfileType.usageLimit), isTrue);
    });

    test('returns false when the bit is not set', () {
      expect(ProfileType.hasType(ProfileType.time, ProfileType.location),
          isFalse);
    });

    test('returns false on empty combinations', () {
      expect(ProfileType.hasType(0, ProfileType.time), isFalse);
    });

    test('detects strictMode (high bit) inside a combination', () {
      final combinations = ProfileType.strictMode | ProfileType.time;
      expect(
          ProfileType.hasType(combinations, ProfileType.strictMode), isTrue);
      expect(ProfileType.hasType(combinations, ProfileType.time), isTrue);
    });
  });

  group('ProfileType.addType', () {
    test('adding to empty produces just the type', () {
      expect(ProfileType.addType(0, ProfileType.time), 1);
    });

    test('combining time + location yields 3', () {
      expect(ProfileType.addType(ProfileType.time, ProfileType.location), 3);
    });

    test('adding an already-present type is idempotent', () {
      final base = ProfileType.time | ProfileType.location;
      expect(ProfileType.addType(base, ProfileType.time), base);
    });

    test('strictMode can be added without disturbing low bits', () {
      final result =
          ProfileType.addType(ProfileType.time, ProfileType.strictMode);
      expect(ProfileType.hasType(result, ProfileType.time), isTrue);
      expect(ProfileType.hasType(result, ProfileType.strictMode), isTrue);
    });
  });

  group('ProfileType.removeType', () {
    test('removing one of two types leaves the other', () {
      final combinations = ProfileType.time | ProfileType.wifi;
      expect(
        ProfileType.removeType(combinations, ProfileType.time),
        ProfileType.wifi,
      );
    });

    test('removing an absent type returns input unchanged', () {
      expect(ProfileType.removeType(0, ProfileType.time), 0);
      expect(
        ProfileType.removeType(ProfileType.wifi, ProfileType.time),
        ProfileType.wifi,
      );
    });

    test('removeType is the inverse of addType', () {
      const before = ProfileType.usageLimit;
      final after = ProfileType.addType(before, ProfileType.quickBlock);
      expect(
        ProfileType.removeType(after, ProfileType.quickBlock),
        before,
      );
    });
  });

  group('BlockingMode constants', () {
    test('blocklist == 0, allowlist == 1', () {
      expect(BlockingMode.blocklist, 0);
      expect(BlockingMode.allowlist, 1);
    });

    test('blocklist and allowlist are distinct', () {
      expect(BlockingMode.blocklist, isNot(BlockingMode.allowlist));
    });
  });

  group('PausedUntil constants', () {
    test('notPaused == 0, disabledByUser == -1', () {
      expect(PausedUntil.notPaused, 0);
      expect(PausedUntil.disabledByUser, -1);
    });

    test('sentinel values are distinct from each other', () {
      expect(PausedUntil.notPaused, isNot(PausedUntil.disabledByUser));
    });
  });
}
