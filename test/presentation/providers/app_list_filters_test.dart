import 'package:flutter_test/flutter_test.dart';
import 'package:koru/platform/blocking_channel.dart';
import 'package:koru/presentation/providers/app_list_provider.dart';
import 'package:koru/presentation/providers/app_personalization_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../_helpers/provider_test_utils.dart';

const _nova = 'com.teslacoilsw.launcher';
const _pixelLauncher = 'com.google.android.apps.nexuslauncher';

final _inventory = <InstalledAppInfo>[
  InstalledAppInfo(packageName: 'com.instagram.android', label: 'Instagram'),
  InstalledAppInfo(packageName: 'com.android.settings', label: 'Settings'),
  InstalledAppInfo(packageName: _nova, label: 'Nova Launcher'),
  InstalledAppInfo(packageName: _pixelLauncher, label: 'Pixel Launcher'),
  InstalledAppInfo(packageName: kKoruPackage, label: 'Koru'),
];

/// I launcher come li vede il nativo: CATEGORY_HOME include Koru, che è un
/// launcher a tutti gli effetti.
const _launchers = {_nova, _pixelLauncher, kKoruPackage};

TestHarness _harness({Set<String> launchers = _launchers}) {
  final h = buildTestContainer(extra: [
    installedAppsProvider.overrideWith((ref) async => _inventory),
    launcherPackagesProvider.overrideWith((ref) async => launchers),
  ]);
  // `visibleAppsProvider` legge la personalizzazione (hidden/rename) da Hive.
  when(() => h.hive.getStringList(any(), any())).thenReturn(const []);
  when(() => h.hive.get<Map<dynamic, dynamic>>(any(), any())).thenReturn(null);
  when(() => h.hive.setStringList(any(), any(), any())).thenAnswer((_) async {});
  return h;
}

Future<void> _warm(TestHarness h) async {
  await h.container.read(installedAppsProvider.future);
  await h.container.read(launcherPackagesProvider.future);
}

List<String> _pkgs(List<InstalledAppInfo> apps) =>
    apps.map((a) => a.packageName).toList();

void main() {
  group('pickerAppsProvider', () {
    test('scarta gli altri launcher E Koru stessa', () async {
      // Il criterio dei picker è lo stesso delle statistiche: voci su cui
      // l'utente non ha motivo di agire — tappare un altro launcher non porta
      // da nessuna parte, e bloccare Koru con Koru non vuol dire niente.
      final h = _harness();
      addTearDown(h.dispose);
      await _warm(h);

      expect(
        _pkgs(h.container.read(pickerAppsProvider)),
        ['com.instagram.android', 'com.android.settings'],
      );
    });

    test('tiene le app di sistema che hanno un\'icona', () async {
      // "App di sistema" NON significa FLAG_SYSTEM: su un Pixel YouTube,
      // Chrome e Gmail sono preinstallate. Filtrare su quel flag nasconderebbe
      // esattamente le app che l'utente vuole limitare.
      final h = _harness();
      addTearDown(h.dispose);
      await _warm(h);

      expect(
        _pkgs(h.container.read(pickerAppsProvider)),
        contains('com.android.settings'),
      );
    });

    test('scarta i launcher di terze parti, non solo quelli noti', () async {
      // Il set arriva da CATEGORY_HOME (dinamico), non da una denylist: Nova
      // non è in nessuna lista hardcoded eppure deve sparire.
      final h = _harness();
      addTearDown(h.dispose);
      await _warm(h);

      expect(_pkgs(h.container.read(pickerAppsProvider)), isNot(contains(_nova)));
    });

    test('fail-open: se la query launcher fallisce non svuota la lista',
        () async {
      // Set vuoto = query al PackageManager fallita, non "device senza
      // launcher". Meglio una voce di troppo che un picker vuoto.
      final h = _harness(launchers: const {});
      addTearDown(h.dispose);
      await _warm(h);

      final pkgs = _pkgs(h.container.read(pickerAppsProvider));
      expect(pkgs, contains(_nova));
      // Koru resta esclusa comunque: non dipende dalla query.
      expect(pkgs, isNot(contains(kKoruPackage)));
    });

    test('NON applica il filtro delle app nascoste', () async {
      // È la differenza che rende `pickerAppsProvider` distinto da
      // `visibleAppsProvider`: `app_personalization_screen` deve poter
      // ri-mostrare un'app nascosta, e un picker che la togliesse renderebbe
      // impossibile impostarci sopra un limite.
      final h = _harness();
      addTearDown(h.dispose);
      await _warm(h);
      await h.container
          .read(appPersonalizationProvider.notifier)
          .toggleHidden('com.instagram.android');

      expect(
        _pkgs(h.container.read(pickerAppsProvider)),
        contains('com.instagram.android'),
      );
    });
  });

  group('visibleAppsProvider (drawer)', () {
    test('scarta gli altri launcher ma TIENE Koru', () async {
      // Le due metà del caso speciale: fuori dai picker e dalle statistiche
      // (come launcher predefinito monopolizzerebbe tutto), dentro il drawer
      // (chi ha cambiato launcher deve poterla riaprire da lì). Finora questa
      // invariante non era coperta da alcun test — l'unico che tocca il
      // provider lo sostituisce con una lista finta.
      final h = _harness();
      addTearDown(h.dispose);
      await _warm(h);

      final pkgs = _pkgs(h.container.read(visibleAppsProvider));
      expect(pkgs, contains(kKoruPackage));
      expect(pkgs, isNot(contains(_nova)));
      expect(pkgs, isNot(contains(_pixelLauncher)));
    });
  });
}
