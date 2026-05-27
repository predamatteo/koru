import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/presentation/providers/notification_filter_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  setUpAll(() {
    // Per any() su List<String> in setSilencedPackages.
    registerFallbackValue(<String>[]);
  });

  group('NotificationFilterNotifier', () {
    test('build() loads silenced packages from blocking channel', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getSilencedPackages())
          .thenAnswer((_) async => ['com.x', 'com.y']);

      final value =
          await h.container.read(notificationFilterProvider.future);
      expect(value, {'com.x', 'com.y'});
      verify(() => h.blocking.getSilencedPackages()).called(1);
    });

    test('build() returns empty set when no packages are silenced',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getSilencedPackages())
          .thenAnswer((_) async => const []);

      final value =
          await h.container.read(notificationFilterProvider.future);
      expect(value, isEmpty);
    });

    test('toggle() adds a package and calls setSilencedPackages', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getSilencedPackages())
          .thenAnswer((_) async => const []);
      when(() => h.blocking.setSilencedPackages(any()))
          .thenAnswer((_) async => true);

      // Force la build.
      await h.container.read(notificationFilterProvider.future);

      await h.container
          .read(notificationFilterProvider.notifier)
          .toggle('com.x');

      expect(
        h.container.read(notificationFilterProvider).valueOrNull,
        {'com.x'},
      );
      verify(() => h.blocking.setSilencedPackages(['com.x'])).called(1);
    });

    test('toggle() removes a package already in the set', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getSilencedPackages())
          .thenAnswer((_) async => ['com.x']);
      when(() => h.blocking.setSilencedPackages(any()))
          .thenAnswer((_) async => true);

      await h.container.read(notificationFilterProvider.future);
      expect(
        h.container.read(notificationFilterProvider).valueOrNull,
        {'com.x'},
      );

      await h.container
          .read(notificationFilterProvider.notifier)
          .toggle('com.x');

      expect(
        h.container.read(notificationFilterProvider).valueOrNull,
        isEmpty,
      );
      verify(() => h.blocking.setSilencedPackages(<String>[])).called(1);
    });

    test('clearAll() resets state and calls setSilencedPackages([])',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getSilencedPackages())
          .thenAnswer((_) async => ['com.x', 'com.y']);
      when(() => h.blocking.setSilencedPackages(any()))
          .thenAnswer((_) async => true);

      await h.container.read(notificationFilterProvider.future);

      await h.container.read(notificationFilterProvider.notifier).clearAll();

      expect(
        h.container.read(notificationFilterProvider).valueOrNull,
        isEmpty,
      );
      verify(() => h.blocking.setSilencedPackages(<String>[])).called(1);
    });

    test('toggle() handles a native save failure without throwing (CR-09)',
        () async {
      // CR-09: setSilencedPackages ora puo' ritornare `false` (scrittura
      // nativa fallita). Il provider DEVE comunque invocare il canale e non
      // crashare: lo stato ottimistico resta, il fallimento e' loggato.
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.getSilencedPackages())
          .thenAnswer((_) async => const []);
      when(() => h.blocking.setSilencedPackages(any()))
          .thenAnswer((_) async => false);

      await h.container.read(notificationFilterProvider.future);

      await h.container
          .read(notificationFilterProvider.notifier)
          .toggle('com.x');

      // Lo stato ottimistico e' applicato e la chiamata nativa e' avvenuta.
      expect(
        h.container.read(notificationFilterProvider).valueOrNull,
        {'com.x'},
      );
      verify(() => h.blocking.setSilencedPackages(['com.x'])).called(1);
    });
  });

  group('notificationAccessGrantedProvider', () {
    test('forwards isNotificationAccessGranted from the channel',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.isNotificationAccessGranted())
          .thenAnswer((_) async => true);

      final granted =
          await h.container.read(notificationAccessGrantedProvider.future);
      expect(granted, isTrue);
    });

    test('returns false when channel says not granted', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.blocking.isNotificationAccessGranted())
          .thenAnswer((_) async => false);

      final granted =
          await h.container.read(notificationAccessGrantedProvider.future);
      expect(granted, isFalse);
    });
  });
}
