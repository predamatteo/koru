import 'package:flutter_test/flutter_test.dart';
import 'package:koru/presentation/providers/accessibility_health_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  // Il provider usa `WidgetsBinding.instance.addObserver` → serve il binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('accessibilityHealthProvider', () {
    test('emits the result of checkAccessibilityService on first tick',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.permission.checkAccessibilityService())
          .thenAnswer((_) async => true);

      final first =
          await h.container.read(accessibilityHealthProvider.stream).first;
      expect(first, isTrue);
      verify(() => h.permission.checkAccessibilityService())
          .called(greaterThanOrEqualTo(1));
    });

    test('emits false when the native check returns false', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.permission.checkAccessibilityService())
          .thenAnswer((_) async => false);

      final first =
          await h.container.read(accessibilityHealthProvider.stream).first;
      expect(first, isFalse);
    });

    test('emits false when the native check throws', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.permission.checkAccessibilityService())
          .thenThrow(Exception('platform fail'));

      final first =
          await h.container.read(accessibilityHealthProvider.stream).first;
      // Eccezioni vengono silenziate, lo stream emette `false`.
      expect(first, isFalse);
    });
  });
}
