import 'package:flutter_test/flutter_test.dart';
import 'package:koru/core/constants/hive_keys.dart';
import 'package:koru/core/constants/profile_types.dart';
import 'package:koru/platform/blocking_channel.dart';
import 'package:koru/presentation/providers/app_limits_provider.dart';
import 'package:koru/presentation/providers/launcher_swipe_actions_provider.dart';
import 'package:koru/presentation/providers/profile_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

void main() {
  group('LauncherSwipeAction encode/decode', () {
    test('round-trips every action type', () {
      const none = LauncherSwipeAction(LauncherSwipeActionType.none);
      const allApps = LauncherSwipeAction(LauncherSwipeActionType.allApps);
      const search = LauncherSwipeAction(LauncherSwipeActionType.appSearch);
      const openApp = LauncherSwipeAction(
        LauncherSwipeActionType.openApp,
        packageName: 'com.whatsapp',
      );

      expect(LauncherSwipeAction.decode(none.encode()), none);
      expect(LauncherSwipeAction.decode(allApps.encode()), allApps);
      expect(LauncherSwipeAction.decode(search.encode()), search);
      expect(LauncherSwipeAction.decode(openApp.encode()), openApp);
    });

    test('openApp encodes with the package suffix', () {
      const a = LauncherSwipeAction(
        LauncherSwipeActionType.openApp,
        packageName: 'com.x',
      );
      expect(a.encode(), 'openApp:com.x');
    });

    test('decode of null/empty/garbage falls back to none', () {
      expect(LauncherSwipeAction.decode(null), LauncherSwipeAction.none);
      expect(LauncherSwipeAction.decode(''), LauncherSwipeAction.none);
      expect(LauncherSwipeAction.decode('whatever'), LauncherSwipeAction.none);
    });

    test('openApp without a package degrades to none', () {
      expect(LauncherSwipeAction.decode('openApp:'), LauncherSwipeAction.none);
    });
  });

  group('LauncherSwipeActionsNotifier', () {
    test('defaults: left/right=none when nothing stored', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.hive.get<String>(any(), any())).thenReturn(null);

      final actions = h.container.read(launcherSwipeActionsProvider);
      expect(actions[LauncherSwipeDirection.left], LauncherSwipeAction.none);
      expect(actions[LauncherSwipeDirection.right], LauncherSwipeAction.none);
    });

    test('build() decodes stored values per direction', () {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.hive.get<String>(any(), any())).thenReturn(null);
      when(() => h.hive
              .get<String>(HiveKeys.uiStateBox, HiveKeys.launcherSwipeRight))
          .thenReturn('openApp:com.maps');

      final actions = h.container.read(launcherSwipeActionsProvider);
      expect(actions[LauncherSwipeDirection.right]!.type,
          LauncherSwipeActionType.openApp);
      expect(actions[LauncherSwipeDirection.right]!.packageName, 'com.maps');
    });

    test('set persists the encoded action and updates state', () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      when(() => h.hive.get<String>(any(), any())).thenReturn(null);
      when(() => h.hive.put(any(), any(), any())).thenAnswer((_) async {});

      final notifier = h.container.read(launcherSwipeActionsProvider.notifier);
      await notifier.set(
        LauncherSwipeDirection.left,
        const LauncherSwipeAction(LauncherSwipeActionType.appSearch),
      );

      expect(
        h.container.read(launcherSwipeActionsProvider)[
            LauncherSwipeDirection.left],
        const LauncherSwipeAction(LauncherSwipeActionType.appSearch),
      );
      verify(() => h.hive.put(
            HiveKeys.uiStateBox,
            HiveKeys.launcherSwipeLeft,
            'appSearch',
          )).called(1);
    });

    test('clear deletes the key and resets to the lateral default (none)',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);
      // Lo stub generico va registrato PRIMA di quello specifico: in mocktail
      // l'ultimo `when` che matcha vince, quindi lo specifico deve venire dopo.
      when(() => h.hive.get<String>(any(), any())).thenReturn(null);
      when(() => h.hive
              .get<String>(HiveKeys.uiStateBox, HiveKeys.launcherSwipeLeft))
          .thenReturn('appSearch');
      when(() => h.hive.delete(any(), any())).thenAnswer((_) async {});

      // Stored "appSearch" is reflected in state.
      expect(
        h.container
            .read(launcherSwipeActionsProvider)[LauncherSwipeDirection.left]!
            .type,
        LauncherSwipeActionType.appSearch,
      );

      final notifier = h.container.read(launcherSwipeActionsProvider.notifier);
      await notifier.clear(LauncherSwipeDirection.left);

      // Back to the lateral default (none).
      expect(
        h.container
            .read(launcherSwipeActionsProvider)[LauncherSwipeDirection.left],
        LauncherSwipeAction.none,
      );
      verify(() => h.hive
          .delete(HiveKeys.uiStateBox, HiveKeys.launcherSwipeLeft)).called(1);
    });
  });

  group('distractingAppsProvider', () {
    test(
        'unions blocklist-profile apps + daily limits, excludes allowlist apps',
        () async {
      final h = buildTestContainer();
      addTearDown(h.dispose);

      when(() => h.profileCh.notifyProfileChanged(any()))
          .thenAnswer((_) async {});
      when(() => h.blocking.getAppDailyLimits()).thenAnswer(
        (_) async => {
          'com.limited': const AppLimitConfig(minutes: 30, strict: false),
        },
      );

      final repo = h.container.read(profileRepositoryProvider);
      final blockId = await repo.createProfile(
        title: 'Block',
        blockingMode: BlockingMode.blocklist,
      );
      await repo.setAppsForProfile(blockId, ['com.insta', 'com.tiktok']);
      final allowId = await repo.createProfile(
        title: 'Allow',
        blockingMode: BlockingMode.allowlist,
      );
      await repo.setAppsForProfile(allowId, ['com.allowed']);

      // Assicura che gli stream/async provider abbiano emesso prima di leggere
      // il provider sincrono.
      keepProviderAlive(h.container, profilesProvider);
      keepProviderAlive(h.container, appLimitsProvider);
      await h.container.read(profilesProvider.future);
      await h.container.read(appLimitsProvider.future);

      final set = h.container.read(distractingAppsProvider);
      expect(set, containsAll(<String>['com.insta', 'com.tiktok', 'com.limited']));
      expect(set, isNot(contains('com.allowed')));
    });
  });
}
