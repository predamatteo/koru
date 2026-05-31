import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../platform/blocking_channel.dart';
import 'app_personalization_provider.dart';

/// Lista completa di app installate (caricata una volta dal native).
///
/// `keepAlive`: previene auto-dispose quando l'unico subscriber sparisce
/// per anche un solo frame. In modalita' "Koru default launcher" l'unico
/// consumer steady-state e' la FavoritesList sotto LauncherHomeScreen;
/// durante navigazioni rapide (HOME intent re-emesso, push/pop di
/// `/launcher/drawer`, transizione fra LauncherHomeScreen e HomeScreen via
/// shortcut "K") il listener puo' venire brevemente smontato — senza
/// keepAlive Riverpod disponeva il provider, e al re-subscribe ripartiva
/// da `AsyncLoading` puro **senza previous**. Risultato: i downstream
/// (`favoriteAppsProvider`, `filteredAppsProvider`) leggevano `valueOrNull`
/// su un loading puro → null → favoriti spariti / drawer vuoto per 1-3s
/// finche' il fetch nativo non completava (PackageManager scan + decode
/// icone PNG). Trade-off: ~200KB-1MB di icone decoded restano in memoria
/// anche se nessuno guarda — costo trascurabile su qualunque device
/// moderno, e su steady-state e' comunque sempre subscribed via pre-warm
/// in `HomeScreen` (tab Home dashboard) e `LauncherHomeScreen` (home del
/// launcher quando Koru e' default), che insieme coprono entrambi i
/// possibili entry-point cold-start dell'app.
final installedAppsProvider = FutureProvider<List<InstalledAppInfo>>((ref) async {
  ref.keepAlive();
  final blocking = ref.watch(platformChannelServiceProvider).blocking;
  return blocking.getInstalledApps();
});

/// Set di package installati senza label né icone. Endpoint native cheap
/// (`getInstalledPackageNames`, ~50ms) che non decoda le bitmap come fa
/// invece `getInstalledApps` (1-3s al cold start).
///
/// Esiste come provider separato perché i consumer che servono SOLO un
/// "questo package è ancora installato?" (TodayLimitsCard filter, future
/// guard simili) non devono aspettare il decode delle icone. Senza questo,
/// la card "Today's limits" mostrava per ~3s entries fantasma di app già
/// disinstallate, fino a quando `installedAppsProvider` finiva di caricare
/// e il filtro UI poteva applicarsi.
///
/// Invalidazione: parallela a `installedAppsProvider` — i due sono
/// fotografie consistenti dello stesso PackageManager a un istante T, e
/// devono essere rinfrescati insieme (vedi `events_refresher.dart`).
final installedPackageNamesProvider = FutureProvider<Set<String>>((ref) async {
  // keepAlive parallelo a [installedAppsProvider] — i due sono fotografie
  // dello stesso PackageManager e devono restare entrambi vivi per la
  // sessione, altrimenti `TodayLimitsCard` perde il filtro ed espone
  // entries fantasma di app disinstallate (lo stesso sintomo gia' fixato
  // in 7102d54 ma ricomparente quando il provider auto-dispone).
  ref.keepAlive();
  final blocking = ref.watch(platformChannelServiceProvider).blocking;
  final names = await blocking.getInstalledPackageNames();
  return names.toSet();
});

/// Set di package che dichiarano un'activity HOME (sono altri launcher
/// installati: Nova, Pixel Launcher, AGM Launcher, ecc.). Usati per
/// filtrare il drawer di Koru — mostrare un altro launcher tra le app
/// confonde l'utente perché tap su Pixel Launcher non fa nulla di
/// significativo (Android lo apre come app, non come launcher).
///
/// Implementato come call diretta al `com.koru/blocking` channel senza
/// passare da `BlockingChannel` per non doverlo allargare; il backing è
/// lo stesso method channel.
final launcherPackagesProvider = FutureProvider<Set<String>>((ref) async {
  const channel = MethodChannel('com.koru/blocking');
  try {
    final raw =
        await channel.invokeListMethod<String>('getLauncherPackageNames');
    return raw?.toSet() ?? const <String>{};
  } catch (_) {
    // Se la query fallisce (channel down al boot, OEM con restrizione)
    // ritorniamo set vuoto: nessun filtro è meglio che crash.
    return const <String>{};
  }
});

/// Icona di una singola app, caricata on-demand dal nativo (decode su thread
/// di background, vedi [BlockingChannel.getAppIcon]). `autoDispose` + `family`:
/// l'icona si carica solo per i package effettivamente mostrati (picker e
/// settings) e viene rilasciata quando la schermata si chiude — niente più
/// decode di TUTTE le icone al cold start né bytes residenti per app mai viste.
final appIconProvider =
    FutureProvider.autoDispose.family<Uint8List?, String>((ref, packageName) {
  return ref
      .watch(platformChannelServiceProvider)
      .blocking
      .getAppIcon(packageName);
});

/// Query di ricerca corrente nella drawer bar.
final appSearchQueryProvider = StateProvider<String>((_) => '');

/// App filtrate per la query + personalization (rinominate con nome
/// custom, hidden escluse dal drawer). Le app rinominate sono ricercate
/// sia per label originale sia per nome custom.
///
/// Filtra anche gli altri launcher installati: senza questo filtro il
/// drawer mostra Nova/Pixel Launcher/AGM e tap su quegli entry non porta
/// l'utente da nessuna parte (Android NON apre un launcher come app
/// normale, lo tratta solo come candidato HOME). Koru stessa NON viene
/// filtrata (anche se ha CATEGORY_HOME): l'utente la cerca esplicitamente.
/// Lista BASE del drawer: app visibili (no hidden, no altri launcher), con
/// rename applicato, ordinate alfabeticamente. NON dipende dalla query →
/// ricomputata solo quando cambia l'inventario / la personalizzazione / il set
/// dei launcher, NON a ogni keystroke di ricerca (vedi [filteredAppsProvider]).
///
/// Stale-while-revalidate: legge `installedAppsProvider` con `.valueOrNull`,
/// che per contratto ritorna il valore precedente durante
/// l'AsyncLoading.copyWithPrevious → il drawer resta pieno mentre
/// `getInstalledApps` rifà lo scan PackageManager. NON usare `unwrapPrevious()`:
/// scarterebbe il previous → lista vuota per tutto il reload (errore storico di
/// 73d174c/e3c930d). Sul cold start (no previous) resta vuota.
final visibleAppsProvider = Provider<List<InstalledAppInfo>>((ref) {
  final apps = ref.watch(installedAppsProvider).valueOrNull ?? const [];
  final personalization = ref.watch(appPersonalizationProvider);
  final launcherPkgs =
      ref.watch(launcherPackagesProvider).valueOrNull ?? const <String>{};
  // Hardcoded: il package di Koru stessa. Volutamente NON filtrato dal drawer
  // anche se compare nel set launcher (l'utente vuole poterla aprire da lì se
  // ha cambiato launcher di default).
  const koruPkg = 'com.dev.koru';

  // Applica rename: produciamo nuovi InstalledAppInfo con label custom (stesso
  // packageName) così tutto il resto della UI usa la label corretta.
  final withNames = <InstalledAppInfo>[];
  for (final a in apps) {
    if (personalization.isHidden(a.packageName)) continue;
    if (a.packageName != koruPkg && launcherPkgs.contains(a.packageName)) {
      continue;
    }
    final custom = personalization.customName(a.packageName);
    withNames.add(
      custom == null
          ? a
          : InstalledAppInfo(packageName: a.packageName, label: custom),
    );
  }
  withNames.sort(
    (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
  );
  return withNames;
});

/// App filtrate per la query corrente. Query vuota → ritorna la lista base già
/// ordinata; altrimenti applica SOLO il filtro (per label o package). È l'unico
/// provider che dipende da [appSearchQueryProvider]: typing ricomputa il
/// filtro, non più map+sort dell'intera lista (la base è memoizzata sopra).
final filteredAppsProvider = Provider<List<InstalledAppInfo>>((ref) {
  final base = ref.watch(visibleAppsProvider);
  final query = ref.watch(appSearchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return base;
  return base
      .where((a) =>
          a.label.toLowerCase().contains(query) ||
          a.packageName.toLowerCase().contains(query))
      .toList(growable: false);
});

/// App raggruppate per lettera iniziale (A-Z, # per non-alfabetiche).
final groupedAppsProvider = Provider<Map<String, List<InstalledAppInfo>>>((ref) {
  final apps = ref.watch(filteredAppsProvider);
  final groups = <String, List<InstalledAppInfo>>{};
  for (final app in apps) {
    // PERF: check su code-unit invece di `RegExp(r'^[A-Z]$')` compilata per
    // OGNI app (Dart non interna i pattern → un'alloc/compile a voce, ripetuta
    // a ogni keystroke nella ricerca). Comportamento invariato: solo A-Z ASCII
    // fanno sezione propria; tutto il resto (cifre, simboli, lettere accentate,
    // grapheme multi-unit) finisce in '#'.
    final label = app.label;
    var key = '#';
    if (label.isNotEmpty) {
      final c = label.codeUnitAt(0);
      if (c >= 0x41 && c <= 0x5A) {
        key = label[0]; // già maiuscola A-Z
      } else if (c >= 0x61 && c <= 0x7A) {
        key = String.fromCharCode(c - 0x20); // minuscola a-z → maiuscola
      }
    }
    groups.putIfAbsent(key, () => []).add(app);
  }
  final orderedKeys = groups.keys.toList()
    ..sort((a, b) => a == '#'
        ? 1
        : b == '#'
            ? -1
            : a.compareTo(b));
  return {for (final k in orderedKeys) k: groups[k]!};
});
