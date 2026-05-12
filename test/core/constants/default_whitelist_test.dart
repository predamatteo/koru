import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/default_whitelist.dart';

void main() {
  group('kDefaultFocusWhitelist contents', () {
    test('contains Koru itself (com.dev.koru)', () {
      expect(kDefaultFocusWhitelist, contains('com.dev.koru'));
    });

    test('contains a Pixel launcher entry', () {
      expect(
        kDefaultFocusWhitelist,
        contains('com.google.android.apps.nexuslauncher'),
      );
    });

    test('contains at least one dialer (Google dialer)', () {
      expect(kDefaultFocusWhitelist, contains('com.google.android.dialer'));
    });

    test('contains at least one camera app (com.android.camera)', () {
      expect(kDefaultFocusWhitelist, contains('com.android.camera'));
    });

    test('contains at least one clock app (Google Clock)', () {
      expect(kDefaultFocusWhitelist, contains('com.google.android.deskclock'));
    });

    test('contains Google Quick Search Box (Search/Assistant/Discover)', () {
      expect(
        kDefaultFocusWhitelist,
        contains('com.google.android.googlequicksearchbox'),
      );
    });
  });

  group('kDefaultFocusWhitelist shape', () {
    test('is a Set<String>', () {
      expect(kDefaultFocusWhitelist, isA<Set<String>>());
    });

    test('every entry looks like a valid Android package name (contains ".")',
        () {
      for (final pkg in kDefaultFocusWhitelist) {
        expect(
          pkg.contains('.'),
          isTrue,
          reason: 'Package "$pkg" does not contain a "."',
        );
      }
    });

    test('every entry is non-empty and contains no whitespace', () {
      for (final pkg in kDefaultFocusWhitelist) {
        expect(pkg, isNotEmpty);
        expect(pkg.contains(' '), isFalse, reason: 'Package "$pkg" has space');
        expect(pkg.contains('\t'), isFalse, reason: 'Package "$pkg" has tab');
      }
    });

    test('no duplicate entries (Set invariant)', () {
      // Set construction would have collapsed dupes — re-assert by length.
      final asList = kDefaultFocusWhitelist.toList();
      expect(asList.toSet().length, asList.length);
    });

    test('attempting to mutate the const set throws (immutable)', () {
      expect(
        () => kDefaultFocusWhitelist.add('com.example.bogus'),
        throwsUnsupportedError,
      );
    });
  });

  group('kDefaultFocusWhitelist coverage of OEM variants', () {
    test('covers at least 3 different launcher OEMs', () {
      final launchers = kDefaultFocusWhitelist.where((p) =>
          p.contains('launcher') || p.contains('home') || p.contains('nexus'));
      expect(launchers.length, greaterThanOrEqualTo(3));
    });

    test('covers at least 2 different clock packages', () {
      final clocks = kDefaultFocusWhitelist.where((p) =>
          p.contains('clock') ||
          p.contains('alarm') ||
          p.contains('worldclock'));
      expect(clocks.length, greaterThanOrEqualTo(2));
    });
  });
}
