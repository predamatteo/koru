# Koru — Analisi di Performance (FREEZE / RELOAD / STUTTER)

**Data:** 2026-05-31
**Autore:** Performance Engineering (Flutter + Android)
**Scope:** 25 finding di audit verificati in modo avversariale (impatto reale + valutazione della fix). Contesto: Koru è spesso il **launcher di default**, quindi `AppLifecycleState.resumed` scatta moltissimo e l'EventChannel Flutter è in pausa in background.

> **Nota metodologica.** Ogni finding è stato sottoposto a verdetto avversariale: codice riletto alla sorgente (incluso il sorgente Flutter SDK e l'engine), severità riallineata all'impatto **reale** misurabile, e fix validata anche sul piano della **correttezza/sicurezza del blocco**. I finding `uncertain` con impatto `minor` sono stati declassati o scartati e raccolti in coda. Tutte le fix proposte qui **non toccano i guard di enforcement nativi** salvo dove esplicitamente indicato.

---

## 1. Verdetto: causa #1 sospetta per sintomo

| Sintomo | Causa-radice #1 | File:riga | In breve |
|---|---|---|---|
| **FREEZE** (jank lungo / ANR) | `StrictModeEnforcer.handleEvent` ricostruisce `EncryptedSharedPreferences` + accede al Keystore (1-2 IPC) ad **ogni window-state-change**, sul **main thread** del processo del launcher (`CACHE_MS = 0`) | `android/.../strictmode/StrictModeStore.kt:286-302` (+ `StrictModeEnforcer.kt:109`, chiamato da `KoruAccessibilityService.kt:674`) | Il servizio gira nel **main process** (non `:accessibility`, vedi `AndroidManifest.xml:79`). Ogni switch di app/recents/multi-window = round-trip Keystore sincrono → jank ai cambi di contesto, ANR nei burst di `TYPE_WINDOWS_CHANGED`. |
| **RELOAD** (provider che si ricaricano "senza motivo") | `appLifecycleInvalidatorProvider` invalida 7 provider + lancia una chiamata nativa **ad ogni resume**, incondizionatamente | `lib/presentation/providers/events_refresher.dart:15-23, 172-182` | Con Koru launcher, `resumed` scatta a ogni gesto-home. Concausa: il canale eventi è inaffidabile (vedi sotto), quindi l'invalidate-su-resume è una **pezza** a eventi persi. |
| **STUTTER** (micro-jank scroll/typing) | Duplice: (a) **collisione di 4 subscriber sullo stesso EventChannel** → eventi persi + teardown non deterministico del canale → invalidazioni mancate/duplicate; (b) **search senza debounce** + lista app **non virtualizzata** che ricostruisce ~150-300 widget per keystroke | (a) `lib/platform/service_event_channel.dart:91-101`; (b) `lib/presentation/screens/all_apps/widgets/app_search_bar.dart:76-77` + `app_list_view.dart:60-65` | Lo stutter "device-wide" sospettato da `ColorFiltered.matrix` è in realtà **gated da un toggle OFF di default**: probabile ma non dominante. Il typing-stutter è reale e locale al drawer. |

**Sintesi della causa comune.** Tre dei sintomi convergono su un singolo anti-pattern di fondo: **lavoro non gateato eseguito ad alta frequenza su hot path** — il resume in Dart (RELOAD), il window-state-change in Kotlin (FREEZE), e l'inaffidabilità del canale eventi che obbliga a quelle pezze (RELOAD/STUTTER). Risolvere il canale e gateare il resume elimina la maggior parte del churn.

---

## 2. Top quick wins (ordinate per impatto/sforzo)

> Ogni voce indica `file:riga`, modifica concreta, rischio/sforzo.

1. **Memoizzare l'istanza `EncryptedSharedPreferences` nello StrictModeStore** — `android/.../strictmode/StrictModeStore.kt:286-302`.
   Sostituire la costruzione ex-novo di `MasterKey.Builder().build()` + `EncryptedSharedPreferences.create(...)` ad ogni `readMask` con un campo `@Volatile private var prefs: SharedPreferences?` con double-checked locking (cachare solo l'istanza **non-null**, ritentare se null per compatibilità Robolectric). **Elimina il round-trip Keystore sul main thread nel caso comune (mask==0).** — *Rischio/Sforzo: S.* È la fix #1 contro il FREEZE.

2. **Un solo broadcast stream condiviso per l'EventChannel** — `lib/platform/service_event_channel.dart:91-101`.
   Mantenere **una sola** subscription mai cancellata per la vita dell'app e fare fan-out via `StreamController.broadcast` statico (vedi codice in §3-Stutter). Ripristina il recapito affidabile di `BLOCKING_STATE`/`PACKAGE_CHANGED`/`QUICK_BLOCK_TICK`, elimina il clobber dell'handler binario e il teardown a cascata quando una focus screen smonta. **Chiude in un colpo solo i due finding del canale.** — *Rischio/Sforzo: S/M.*

3. **Throttlare e/o offloadare `_smartRefreshInstalledApps` su resume** — `lib/presentation/providers/events_refresher.dart:48-100, 178` + `android/.../AppInventoryCallHandler.kt:60-61`.
   (a) Offloadare `getInstalledPackageNames` su un `Thread{}` di background con `runOnUiThread { result.success(...) }`, **esattamente come già fatto per `getInstalledApps`** (stesso file, righe 45-58); (b) throttlare il diff a max 1 ogni ~30-60s via timestamp. Toglie la scansione `PackageManager` sincrona dal Platform main thread. — *Rischio/Sforzo: S.*

4. **Debounce della search del drawer** — `lib/presentation/screens/all_apps/widgets/app_search_bar.dart:76-77`.
   Avvolgere `ref.read(appSearchQueryProvider.notifier).state = value` in un `Timer` con debounce ~150-200ms (cancellare in `dispose`, bypassare il debounce sul tasto clear/reset esterno). Taglia i ricomputi di `filteredAppsProvider`/`groupedAppsProvider` durante la digitazione veloce. — *Rischio/Sforzo: S.*

5. **Virtualizzare `AppListView` (`ListView.builder` su lista appiattita)** — `lib/presentation/screens/all_apps/widgets/app_list_view.dart:37-65`.
   Appiattire `grouped` in una `List<Object>` (header `String` | `InstalledAppInfo`) calcolata una volta, e renderla con `ListView.builder` + `itemBuilder` (switch sul tipo). **NON usare `itemExtent` fisso**: header (40) e tile (50) scalano con `textScaler`, romperebbe l'ancoraggio della FastScroller (`all_apps_screen.dart:65-83`). Convertire i favoriti in `Set<String>` una volta (`favs.toSet()`) per eliminare `contains` O(n)×2 per tile. — *Rischio/Sforzo: M.*

6. **Rimuovere `profilesProvider` da `_invalidateStats`** — `lib/presentation/providers/events_refresher.dart:22`.
   I profili sono scritti **solo dall'UI Dart** (`ProfileRepository` → `notifyProfileChanged` verso il native, mai viceversa): `Drift.watch` è già reattivo. È l'**unico** dei 7 che ricomputa eagerly sul launcher (ha listener via `launcherSwipeActions`/`activeProfiles`), quindi è lavoro sprecato ad alta frequenza. Lasciarlo in `global_refresh.dart` (pull-to-refresh manuale). — *Rischio/Sforzo: S.*

7. **Avvolgere `setIntervalsForProfile` in `transaction()`** — `lib/data/repositories/profile_repository.dart:172-191`.
   Oggi fa `delete + N insert` **fuori transazione**, generando fino a N+1 ri-emissioni dello stream `watchAllProfiles` (ognuna ricostruisce tutti i `ProfileModel` con loop N+1). Allinearlo a `setAppsForProfile`/`setWifisForProfile` che già usano `transaction()`: collassa le notifiche Drift in una sola al commit (migliora anche l'atomicità). — *Rischio/Sforzo: S.*

---

## 3. Dettaglio per sintomo

I finding duplicati sono stati uniti. La severità riportata è l'`adjusted_severity` del verdetto avversariale.

### 3.A — FREEZE (jank lungo / ANR sul main thread)

#### F1. Keystore + EncryptedSharedPreferences ricostruiti ad ogni window-event — **HIGH**
**File:** `android/app/src/main/kotlin/com/dev/koru/strictmode/StrictModeStore.kt:286-302` (con `StrictModeEnforcer.kt:109-149, 253-275`; chiamato da `KoruAccessibilityService.kt:674`).

**Meccanismo.** `onAccessibilityEvent` chiama `StrictModeEnforcer.handleEvent` **prima** del filtro `skipPackages` (riga 676), quindi anche per launcher/systemui. `getMask()` con `CACHE_MS = 0L` fa sempre `StrictModeStore.readMask(context)` → `encryptedPrefs(context)` che **costruisce ex-novo** `MasterKey.Builder(...).build()` + `EncryptedSharedPreferences.create(...)` ad ogni invocazione (nessuna memoizzazione). Sono **IPC reali verso il Keystore** (master key + AEAD-decrypt del keyset Tink), non letture O(1). Se la mask è attiva (mask≠0), `computeHmac` → `getOrCreateHmacKey` aggiunge un **secondo** round-trip Keystore + HMAC-SHA256. Il commento interno "EncryptedSharedPreferences fa caching interno comunque" è **materialmente sbagliato**: la cache è per-istanza, e qui se ne crea una nuova ogni volta.

**Correzione fattuale rispetto al finding originale:** il servizio **NON** gira in `:accessibility` (il `AndroidManifest.xml:79` non ha `android:process`; i commenti che citano `:accessibility` sono stale, ereditati dalla source app). Gira nel **main process** = processo della UI home → il lavoro Keystore sincrono **compete direttamente col main thread**. `handleEvent` non scatta su typing/scroll (quelli ritornano early), ma scatta ad **ogni cambio di finestra** (apertura/chiusura app, recents, multi-window), in **burst** durante le transizioni che emettono `TYPE_WINDOWS_CHANGED` a raffica.

**Fix (applicare entrambe).**
1. Memoizzare l'istanza in `@Volatile private var prefs: SharedPreferences?` con double-checked locking, condivisa da `readMask`/`saveMask`. Cachare **solo** l'istanza non-null. Non indebolisce la sicurezza (keyset/HMAC/tamper-evidence invariati; legge sempre l'ultimo valore persistito).
2. Reintrodurre una cache della mask in `StrictModeEnforcer` (`CACHE_MS ~1000-2000ms`) invalidata esplicitamente da `setStrictModeOptions` (`StrictModeMethodChannel.kt:157`) e `performEmergencyUnblock` (riga 235). Poiché il servizio è nel main process, `invalidateCache()` invalida **esattamente** la stessa cache in-memory letta dal callback → la motivazione storica di `CACHE_MS=0` (staleness cross-process) **non esiste**. La cache copre il caso mask≠0 (evita l'HMAC ripetuto).

**Nota test:** `StrictModeStoreTest` gira su Robolectric senza Keystore (vedi memoria `reference_kotlin_unit_tests`): il campo memoizzato deve gestire il null da `encryptedPrefs` senza cachare il fallimento. Correggere anche i commenti stale `:accessibility` (`StrictModeStore.kt:45-49`, service `42-45`) per evitare che un futuro dev re-irrigidisca `CACHE_MS=0`. Stesso anti-pattern in `BackdoorCodeGenerator.encryptedPrefs` e `StrictModeMethodChannel.prefs`, ma **fuori** dal hot path.

**Rischio/Sforzo: S.**

---

#### F2. Scansione `PackageManager` sincrona sul Platform main thread ad ogni resume — **LOW** (ma quick win, vedi §2.3)
**File:** `lib/presentation/providers/events_refresher.dart:48-100, 178` + `android/.../AppInventoryCallHandler.kt:60-61`.

**Meccanismo.** `_smartRefreshInstalledApps` (fire-and-forget su ogni resume) chiama `getInstalledPackageNames()`, che lato nativo gira **sincrono sul Platform main thread** (`AppInventoryCallHandler.kt:60-61`), a differenza di `getInstalledApps` che è offloadato su `Thread{}` (righe 45-58). Fa `getInstalledApplications(0)` + `queryIntentActivities` + filter + sort: scansione completa via binder verso `system_server`, ordine dei ~decine di ms su 100-200 package con PM cache fredda.

**Perché LOW e non un freeze reale:** il Platform main thread di Android **non** è il thread su cui Flutter renderizza i frame (UI isolate + raster thread dedicati). È un possibile micro-hitch di **input latency** al momento del resume su device lenti, non un freeze lungo né uno stutter di scroll in steady-state. Il diff è già delta-gated (`getInstalledApps` con decode icone parte **solo** su delta install/uninstall reale → no-op nel caso comune).

**Fix.** (a) Offloadare `getInstalledPackageNames` su `Thread{}` con `runOnUiThread { result.success(...) }` (copia il pattern di `getInstalledApps`); (b) throttlare il diff a max 1 ogni ~30-60s via timestamp nell'observer. Mantenere il `ref.read(appLimitsProvider.future)` in `_cleanupStaleAppLimits` (gira solo su delta reale, serve a non lasciare entry fantasma in `koru_app_limits.json`).

**Rischio/Sforzo: S.**

> **Scartato come causa di FREEZE:** decode icone PNG (`installedAppsProvider`) come freeze al rientro home — il path è offloadato su `Thread{}` di background, awaited non-bloccante, con stale-while-revalidate (`.valueOrNull`/`skipLoadingOnReload`): **non blocca il main isolate**. Resta vero il costo a **cold start** (vedi F-cleanup in §Reload).

---

### 3.B — RELOAD (provider che si ricaricano "senza motivo")

#### R1. Invalidazione incondizionata di 7 provider + chiamata nativa ad ogni resume — **MEDIUM** (causa-radice del RELOAD)
**File:** `lib/presentation/providers/events_refresher.dart:15-23, 172-182` (watchato in root da `app.dart:23`).

> Questo finding **deduplica** tre voci dell'audit (appLifecycleInvalidator, "7 provider + chiamata nativa", "tre WidgetsBindingObserver"). Le tratto qui unite.

**Meccanismo.** `_LifecycleObserver` su **ogni** `AppLifecycleState.resumed` chiama `_invalidateStats(ref)` (7 provider) + `unawaited(_smartRefreshInstalledApps(ref))`. Con Koru launcher, `resumed` scatta a ogni ritorno home/dismissal overlay/task switcher.

**Ridimensionamento avversariale (importante per non sovra-ingegnerizzare):**
- I 7 provider (6 StreamProvider Drift + 1 FutureProvider `todayMoodProvider`) **non sono keepAlive**. In Riverpod 2.6.1 `ref.invalidate` su un provider **senza listener** lo marca solo stale (`scheduleProviderRefresh`) e ricomputa **pigramente** al prossimo `ref.read` — **non** esegue subito la query.
- Quando Koru è launcher, il resume porta a `/launcher` (`LauncherHomeScreen`), route **top-level separata** dallo `StatefulShellRoute` che contiene `HomeScreen`/`StatisticsScreen`. La launcher home **non watcha nessuno** dei 7 provider stats → per il path dominante l'invalidate è quasi un **no-op**.
- L'**unico** dei 7 che ricomputa eagerly anche sul launcher è `profilesProvider` (ha listener via `launcherSwipeActions`/`activeProfiles`) → 1 sola re-query `watchAllProfiles()` per resume.
- Il claim "7 re-query DB ad ogni resume con zero widget stats" è **smentito**. `todayMoodProvider` è un `FutureProvider`, non StreamProvider (errore fattuale minore del finding).

**Perché resta MEDIUM e va comunque fixato.** È churn reale + la concausa strutturale del sintomo RELOAD: l'invalidate-su-resume è una **pezza deliberata** (commenti `events_refresher.dart:159-171`) agli eventi di blocking persi mentre l'EventChannel è in pausa in background. Quella pezza è necessaria **solo perché il canale eventi è inaffidabile** (vedi S1). Sistemato il canale, l'invalidate-su-resume può essere fortemente ridotto.

**Fix (priorità ordinata).**
1. **Rimuovere `profilesProvider` da `_invalidateStats`** (riga 22): i profili non cambiano in background, è l'unico costo eager reale. **SICURO** (writer solo Dart). Mantenerlo in `global_refresh.dart` per il pull-to-refresh.
2. **Throttlare l'intero handler di resume** a max 1 ogni ~30-60s (timestamp ultimo resume): i resume ravvicinati del launcher non rilanciano né invalidazioni né scansione nativa.
3. **NON** gateare `_invalidateStats` dietro timestamp >2-3s in modo aggressivo per "perdere eventi": dopo il fix del canale (S1) gli eventi di blocking arrivano via push affidabile, quindi l'invalidate-su-resume diventa un fallback raro, non il canale primario.

**Rischio/Sforzo: S (fix 1+2).** Nessun impatto su enforcement (nativo). Attenzione a non throttlare male `installedAppsProvider` (bug storico noto: drawer/favoriti vuoti).

---

#### R2. Pull-to-refresh del drawer invalida ~28 provider — **LOW**
**File:** `lib/presentation/screens/all_apps/all_apps_screen.dart:131-146` → `koru_pull_to_refresh.dart:33-37` → `global_refresh.dart:42-105`.

**Meccanismo & ridimensionamento.** Un pull **intenzionale** sul drawer chiama `refreshAllKoruData` che invalida l'intera lista `_koruDataProviders` (~28). MA: (a) per contratto documentato (`global_refresh.dart:96-100`) solo i provider **montati** ricaricano eagerly; sul drawer i soli montati sono la tripletta inventario + favoriti + folders → **niente** raffica di re-fetch stats/usage/mood; (b) il `RefreshIndicator` è standard (nessun `notificationPredicate` custom) → richiede un **drag deliberato**, non un overscroll accidentale. Quindi il claim "RELOAD non richiesto da overscroll involontario" è in gran parte refutato. Resta: un pull intenzionale ri-esegue `getInstalledApps` (scan + decode icone) ridondante, dato che l'inventario si auto-rinfresca già via `PACKAGE_*` e su resume.

**Fix.** Per il drawer, invalidare **solo** `installedAppsProvider` + `installedPackageNamesProvider` + `launcherPackagesProvider` invece di `refreshAllKoruData`. Attenzione: `KoruPullToRefresh` esegue `onRefresh` **prima** di `refreshAllKoruData` incondizionatamente → serve o un flag "esclusivo" su `KoruPullToRefresh`, o un `RefreshIndicator` diretto nel drawer. Più semplice: **rimuovere** il pull-to-refresh dal drawer (l'inventario si auto-rinfresca). Verificare prima che il "pull-to-refresh ovunque" non sia un comportamento di design voluto (`koru_pull_to_refresh.dart:9-12`).

**Rischio/Sforzo: S.**

> **Inventario "grasso" (icone decodificate ma non mostrate nel drawer) — LOW, cleanup opzionale.** `getInstalledApps` decoda/comprime un PNG 96×96 per ogni app, ma `_AppTile`/favoriti/cartelle renderizzano **solo testo** (le icone servono ai picker/settings). È spreco al **cold start** (non "ad ogni reload": il resume usa il path cheap `getInstalledPackageNames`). Fix pulita a rischio zero di divergenza: rendere **lazy** il decode con un endpoint `getAppIcon(packageName)` on-demand usato dai picker dietro `FutureBuilder`/provider `.family`, eliminando anche i ~200KB-1MB residenti in keepAlive. Aggiungere un test di parità del set launchable fra gli endpoint. Priorità bassa.

---

### 3.C — STUTTER (micro-jank scroll/typing)

#### S1. Quattro subscriber sullo stesso EventChannel si clobberano: eventi persi + teardown non deterministico — **HIGH** (causa-radice dello stutter "reload casuale")
**File:** `lib/platform/service_event_channel.dart:91-101` (+ Kotlin `ServiceEventChannel.kt:13-26`).

> Deduplica due voci dell'audit (collisione canale + "ref.watch nel body si ri-listena"). Il titolo del secondo è falso (a regime i provider root **non** rieseguono su invalidate); la causa reale è la collisione, trattata qui.

**Meccanismo (verificato fino all'engine).** `events()` chiama `_channel.receiveBroadcastStream()` **fresco ogni volta** su un unico `EventChannel('com.koru/service_events')`. È invocato da **quattro** subscriber: `blockingEventsRefresherProvider` (`events_refresher.dart:129`), `packageEventsRefresherProvider` (`:201`), `achievementEvaluatorProvider` (`achievement_evaluator.dart:25`), `quickBlockTickProvider` (`focus_session_provider.dart:14`). Nel sorgente Flutter (`platform_channel.dart:693-740`) ogni `receiveBroadcastStream()` crea un nuovo `StreamController.broadcast` il cui `onListen` fa `setMessageHandler(name, ...)` keyed **solo sul channel-name**; l'engine (`channel_buffers.dart`) tiene **un solo listener per canale**: *"Setting a new listener clears the previous one"*. Lato Kotlin c'è **un solo** `@Volatile var eventSink`, sovrascritto a ogni `onListen`.

**Conseguenza.** A regime **solo l'ultimo** controller registrato riceve i byte; gli altri 2-3 `.listen()` sono **orfani** (mai chiamati). Dato l'ordine di init al root (blocking→package→achievement), `blockingEventsRefresherProvider` e `packageEventsRefresherProvider` **non ricevono** eventi dal canale → le loro invalidazioni su `BLOCKING_STATE`/`PACKAGE_CHANGED` **non scattano via canale** (ecco perché esiste la pezza invalidate-su-resume di R1). Peggio: `quickBlockTickProvider` è un StreamProvider non-keepAlive; quando una focus screen smonta, il suo `onCancel` fa `setMessageHandler(name, null)` + native `eventSink=null` → **il canale muore per tutti** finché qualcosa non ri-sottoscrive. Da qui i "reload casuali" e il non-determinismo, con finestre di invalidazioni **duplicate** quando due handler coesistono prima del clobber. Non causa freeze/stutter di frame (nessun lavoro bloccante sul main isolate), ma è la radice del comportamento "provider che si ricaricano senza motivo".

**Fix (Dart-side, preferita — fixa anche il clobber dell'handler binario).**
```dart
class ServiceEventChannel {
  static const EventChannel _channel = EventChannel('com.koru/service_events');
  static final StreamController<KoruServiceEvent> _ctrl =
      StreamController<KoruServiceEvent>.broadcast();
  static StreamSubscription<dynamic>? _upstream;

  Stream<KoruServiceEvent> events() {
    _upstream ??= _channel.receiveBroadcastStream().listen(
      (raw) => _ctrl.add(_decode(raw)),
      onError: _ctrl.addError,
    );
    return _ctrl.stream; // i 4 provider .listen() qui; cancel NON tocca _upstream
  }
}
```
**Un solo** `receiveBroadcastStream` → un solo `setMessageHandler` → un solo `onListen` native → un solo `eventSink`. I dispose dei provider cancellano solo la propria subscription sul broadcast, mai l'upstream. `_ctrl` vive quanto l'app (`platformChannelServiceProvider` è singleton keepAlive, `providers.dart:55-57`). Alternativa Riverpod-pulita: `serviceEventsProvider = StreamProvider((ref){ ref.keepAlive(); return ...events(); })` watchato dai 4 consumer. **NON** basta `.asBroadcastStream()` da solo (cancella l'upstream quando l'ultimo listener stacca). **Nessun rischio enforcement** (canale solo per refresh stats/achievements/inventario); anzi **ripristina** il recapito affidabile di `BLOCKING_STATE`/`PACKAGE_CHANGED`.

**Rischio/Sforzo: S/M.**

---

#### S2. Search senza debounce + lista app non virtualizzata — **MEDIUM**
**File:** `lib/presentation/screens/all_apps/widgets/app_search_bar.dart:76-77` + `app_list_view.dart:37-65` + `app_list_provider.dart:93-157`.

> Deduplica quattro voci dell'audit (AppListView × due, filteredApps, search senza debounce). Il driver dominante del typing-stutter è la combinazione **rebuild eager non virtualizzato + nessun debounce**.

**Meccanismo.** `onChanged` scrive `appSearchQueryProvider` ad **ogni carattere** senza debounce → `filteredAppsProvider` (where + map + sort|where) → `groupedAppsProvider` (re-itera N app + **compila `RegExp(r'^[A-Z]$')` una volta per app**, riga 147, Dart non interna i pattern) → `AppListView.build` ricostruisce l'intera `List<Widget> items` (`ListView(children:)`, **non** `ListView.builder`).

**Ridimensionamento avversariale.**
- `ListView(children:)` usa `SliverChildListDelegate`: pre-alloca tutti gli **oggetti Widget** + closure ad ogni build, MA l'inflate di Element/layout/paint è comunque **lazy** sulla viewport. Quindi `_AppTile.build()` gira solo per le ~15 tile visibili. Il claim "costruisce ed elementizza tutti i 150 figli ogni frame >16ms" è **tecnicamente falso**.
- `_AppTile` è **solo testo** (InkWell + Row + Text + eventuale star Icon): **nessun decode icona**. Allocare ~177 oggetti widget leggeri è sub-ms.
- Il sort col doppio `toLowerCase` gira **solo** quando `query.isEmpty` (transizione clear→vuoto), non a ogni keystroke. I nuovi `InstalledAppInfo` si allocano **solo** per app rinominate (`customName != null`), e `iconBytes` è copia di **puntatore**, non buffer.
- `favs.contains` su `List<String>` è O(n), chiamato **2 volte per tile** (`app_list_view.dart:44,49`) — reale ma secondario.

**Perché MEDIUM (non HIGH).** Il costo per-keystroke è la **reconciliation completa di ~300 widget** + le ~150 compilazioni regex + il re-run di `filteredAppsProvider`. Su 100-150 app è dell'ordine di pochi ms — può sforare 16ms su device entry-level (stutter percepibile), raramente su hardware moderno. Lo scope del rebuild è **circoscritto** al sottoalbero `AppListView` (la `AppSearchBar` è `const` con il suo State).

**Fix (priorità ordinata).**
1. **Debounce** ~150-200ms su `onChanged` (`app_search_bar.dart:76-77`): cancellare in `dispose`, bypassare su clear (`:64-67`) e reset esterno su resume (`all_apps_screen.dart:57-62`). Riduce il numero di ricomputi a fine raffica. **Massima leva per il typing-stutter.**
2. **Virtualizzare** `AppListView` con `ListView.builder` su lista appiattita (vedi §2.5). **NO `itemExtent` fisso** (altezze scalano con `textScaler`). Mantenere coerente `_computeSectionOffsets` con la stessa flat list.
3. `favSet = favs.toSet()` una volta in build (o un `favoriteSetProvider` che espone `Set`).
4. Sostituire `RegExp(r'^[A-Z]$')` con check su code unit: `final c = first.codeUnitAt(0); final isAZ = c >= 0x41 && c <= 0x5A;` (gestisce correttamente grapheme multi-unit → `#`).
5. Opzionale: split di `filteredAppsProvider` in "visible+renamed+sorted" (memoizzato, dipende solo da `installedApps`/`personalization`/`launcherPkgs`) + derivato leggero che applica solo la query. **Nota correttezza:** pre-ordinando la lista stabile, anche i risultati di ricerca diventano alfabetici (oggi escono in ordine di inserimento) — miglioramento, ma verificare che i test UI non assumano l'ordine non-ordinato.

**Rischio/Sforzo: S (1,3,4) + M (2,5).**

---

#### S3. `ColorFiltered.matrix` sull'intero albero (monochrome) — **LOW** (gated da toggle OFF di default)
**File:** `lib/app.dart:36-52`.

**Meccanismo & ridimensionamento.** Quando `monochrome == true` il builder avvolge l'intero albero route in `ColorFiltered(ColorFilter.matrix([...luma...]))`. MA: (a) feature **opt-in, default OFF** (`monochrome_provider.dart`, `defaultValue: false`) → se l'utente non l'ha attivata, il widget **non è nell'albero** e non può spiegare lo stutter generale; (b) `ColorFiltered` → `RenderColorFilter` → `pushColorFilter` spinge un `ColorFilterLayer` **retained** a livello di compositing: non ri-registra il painting dei sottoalberi invariati ogni frame, e la matrice `const` con identità widget stabile fa **riusare** il layer; (c) con **Impeller default-on** (Flutter 3.44, nessun opt-out nel progetto) una color-matrix è uno **shader GPU per-pixel** in compositing, non un readback offscreen CPU costoso; (d) i `ListView`/`CustomScrollView` inseriscono `RepaintBoundary` impliciti per-item che isolano i repaint durante lo scroll. Il "saveLayer offscreen a piena risoluzione ogni frame" è il modello CPU/Skia, **non** la configurazione reale.

**Fix.** PRIMA **misurare** on-device con DevTools/performance overlay con monochrome **ON** durante scroll della lista app (è plausibile che con Impeller il costo sia trascurabile). Se il profiling conferma jank: avvolgere in `RepaintBoundary` i sottoalberi scrollabili/animati, **oppure** applicare il `ColorFiltered` solo al sottoalbero con contenuto colorato (es. lista icone app) invece che alla root.
**DA NON FARE:** sostituire con una `ColorScheme` desaturata come unica soluzione — **rompe la feature**: una ColorScheme tocca solo i colori theme-driven/Material, **non** le icone PNG delle app, che sono proprio ciò che il monochrome deve desaturare.

**Rischio/Sforzo: S (misura) → S/M (fix mirata se serve).**

---

#### S4. `setIntervalsForProfile` fuori transazione → burst di ri-emissioni di `watchAllProfiles` — **MEDIUM**
**File:** `lib/data/repositories/profile_repository.dart:19-51, 172-191`.

**Meccanismo.** `watchAllProfiles` fa `StreamGroup.merge` di 3 watch, due dei quali sono watch di **tabella intera** senza where (`appProfileRelations`, `intervals`). Ogni emissione fa `getAllProfiles` + per ogni profilo 4 query (`_loadRelations`) = **1 + 4·P (N+1)**. `setIntervalsForProfile` fa `delete + N insert` **senza transaction** → salvare 3 fasce = fino a 4 ri-emissioni = 4 ricostruzioni complete di tutti i `ProfileModel`. `profilesProvider` ha fan-out ampio (home, profiles_list, **activeProfilesProvider = catena enforcement**, launcher_swipe_actions).

**Ridimensionamento.** Il DB gira su isolate di background (`NativeDatabase.createInBackground`, `app_database.dart:545`): le 4·P SELECT **non** girano sul main thread; il costo UI-isolate sono i rebuild ripetuti. Il burst parte da un'azione **discreta** di Save (poi `context.pop()`), non da ogni keystroke → il sintomo reale è un **breve hiccup una-tantum alla transizione di pop**, più vicino a un micro-freeze che a stutter continuo. P è tipicamente a una cifra.

**Fix (priorità ordinata).**
1. Avvolgere `setIntervalsForProfile` in `transaction()` come i fratelli `setAppsForProfile`/`setWifisForProfile`: collassa N notifiche in 1 al commit + atomicità (no stato intermedio a 0 fasce osservabile dall'enforcement). **Fix prioritaria, SICURA.**
2. (Opzionale) Eliminare l'N+1 con query batch `WHERE profileId IN (...)` + raggruppamento in Dart.
3. (Opzionale) **NON** `debounceTime` cieco sullo stream: `profilesProvider` alimenta l'enforcement → ritardo rischioso. Se serve coalescing, usare `.distinct()` con deep-equality sulla lista `ProfileModel` (evita rebuild identici senza latenza).

**Rischio/Sforzo: S (fix 1).**

---

### Finding declassati/scartati (uncertain + minor)

Documentati per completezza; **non** spiegano i sintomi riportati e non vanno prioritizzati.

| Finding | File | Verdetto | Nota |
|---|---|---|---|
| `activeProfilesProvider` riavvia `Stream.periodic` su resume | `active_profile_provider.dart:12-51` | LOW | Sul launcher i provider sono smontati (invalidate no-op); il "fan-out su launcher swipe actions" è **falso** (dipende `distractingAppsProvider`, usato solo nello schermo di config). Coperto dal fix "rimuovi profilesProvider da `_invalidateStats`". |
| `achievementEvaluator` lancia ~8 query + 2 native su resume | `achievement_evaluator.dart:24-65`, `achievements_provider.dart:45-93` | LOW | Query su isolate Drift di background, native async; non blocca frame. **Fix utile a costo zero:** debounce/dedup del trigger (achievement idempotenti) + `Future.wait` per parallelizzare; o eliminare il trigger su resume (boot-catchup + event-driven bastano). `watchFocusTimeUsage(...).first` → query one-shot. |
| Provider stats StreamProvider invalidati su resume | `statistics_providers.dart:12-49` | LOW | `copyWithPrevious(isRefresh)` → niente flicker; ~2 rebuild cheap, non 5; query COUNT/GROUP BY su isolate background. `markTablesUpdated` **non** sostituisce l'invalidate (non vede scritture cross-process native). Coalescere le invalidazioni per-evento sotto un debounce (già fatto per package, manca per blocking). |
| `ForegroundDetector.detect()` non cache-ato | `ForegroundDetector.kt:25-72` | LOW | 1 detect/evento nel caso comune (non 2-3); watched set ristretto da `applyDynamicPackageFilter`; fallback 1h e burst sono mutuamente esclusivi. **Fix SICURA:** passare `precomputedForeground` per evitare la 2ª `detect()` nel ramo bypass-revoke; gate del fallback 1h al primo evento post-boot. **DA NON fare:** cache TTL 200-300ms (rompe fail-secure su transizioni rapide). |
| `getCurrentWifiSsid()` letto sempre | `KoruAccessibilityService.kt:1149-1167` | LOW | IPC sprecata quando nessun profilo usa vincolo WiFi, ma su window-state (non per-frame), ≤2/s nei browser. **Fix:** lambda **memoizzata per-evento** (no cache TTL globale, indebolirebbe il gating). |
| `UsageCounter.guardedTodayForegroundMs` query 24h + RMW file | `UsageCounter.kt:31-62, 92-169` | LOW | Su thread di callback distinto dal main looper, gated a app-con-limite su eventi di transizione. **Fix #1 (SICURA):** in `UsageGuardStore.mutate` saltare `writeAtomic` quando `day`+`accumMs` invariati (come `BypassStore`), **ma** aggiornare il `_meta` monotonico per non far invecchiare il riferimento anti clock-backward (SEC-03). Cache del raw `todayForegroundMs` opzionale **preservando** il side-effect `observe`. |
| `accessibility_service_config.xml` riceve content/scroll | `accessibility_service_config.xml:25-32` | LOW | Early-return non-browser quasi gratis (`isBrowser` memoized); path pesante gated a 500ms/pkg; durante scroll nel browser la UI Koru è in background. **Fix a basso rischio:** alzare il throttle browser a ~750ms-1s. **DA NON fare:** togliere browser dal watched set quando mancano website rules (rompe focus/limit iniziato dentro il browser). |

---

## 4. Diagnostica da aggiungere (conferma on-device)

1. **`ProviderObserver` Riverpod** che logga `didUpdateProvider`/`didDisposeProvider`/`didAddProvider` con timestamp e nome provider. Conferma quante invalidazioni partono per resume e **quali** provider ricomputano davvero (vs solo stale-marking). Loggare anche un contatore globale "resume #N → invalidazioni partite #M".
   ```dart
   class PerfObserver extends ProviderObserver {
     @override void didUpdateProvider(p, prev, next, c) =>
       developer.log('[INVALIDATE] ${p.name ?? p.runtimeType} @${DateTime.now().millisecondsSinceEpoch}', name: 'PerfObs');
   }
   // ProviderScope(observers: [PerfObserver()], ...)
   ```
2. **Conteggio resume vs reload:** un counter incrementato in `_LifecycleObserver.didChangeAppLifecycleState(resumed)` confrontato col numero di re-query DB effettive (loggare in cima ai DAO `.watch`/`.get` chiamati). Verifica empiricamente che il path launcher sia "no-op".
3. **Flutter performance overlay** (`MaterialApp.showPerformanceOverlay` o flag DevTools) + **DevTools Timeline** con `monochrome` ON e OFF, durante: apertura drawer, typing in search, scroll lista app, ritorno home. Confronto frame-time UI/raster per isolare S3.
4. **Timing nativo:** loggare `System.nanoTime()` attorno a `StrictModeEnforcer.handleEvent`, `StrictModeStore.readMask` (Keystore), `getInstalledPackageNames`, `getInstalledApps`, `UsageCounter.guardedTodayForegroundMs` (durata + numero righe iterate). Conferma F1/F2.
5. **systrace/Perfetto** sul **main thread del processo `com.dev.koru`** (= main process, dove gira l'accessibility service) durante burst di `TYPE_WINDOWS_CHANGED` (apri recents, multi-window). Cerca slice lunghi su binder Keystore/PackageManager.
6. **Markatura del canale eventi:** loggare lato Kotlin `ServiceEventChannel.onListen/onCancel` (con stack/contatore) e lato Dart il `_decode` di ogni evento ricevuto **per ciascun** subscriber. Conferma S1 (solo 1 subscriber riceve; canale muore quando focus screen smonta).

---

## 5. Piano in fasi

### Fase 1 — Quick wins a basso rischio (S, nessun refactor strutturale)
- **F1.1** Memoizzare `EncryptedSharedPreferences` in `StrictModeStore` (double-checked locking). *(FREEZE #1)*
- **F1.2** `getInstalledPackageNames` su `Thread{}` di background lato Kotlin + throttle 30-60s del diff resume. *(FREEZE/RELOAD)*
- **F1.3** Un solo broadcast stream condiviso in `ServiceEventChannel`. *(STUTTER/RELOAD radice — S1)*
- **F1.4** Debounce 150-200ms sulla search del drawer. *(STUTTER typing)*
- **F1.5** Rimuovere `profilesProvider` da `_invalidateStats` + throttle handler resume. *(RELOAD)*
- **F1.6** `setIntervalsForProfile` in `transaction()`. *(STUTTER editing profili)*
- **F1.7** `favs.toSet()` + check code-unit al posto della RegExp in `groupedAppsProvider`. *(STUTTER typing)*

### Fase 2 — Refactor strutturali (M)
- **F2.1** Reintrodurre cache della mask in `StrictModeEnforcer` (`CACHE_MS 1-2s`, invalidata su `setStrictModeOptions`/`performEmergencyUnblock`); correggere i commenti stale `:accessibility`. *(FREEZE, copre mask≠0)*
- **F2.2** Virtualizzare `AppListView` (`ListView.builder` su lista appiattita, no `itemExtent` fisso; coerenza FastScroller). *(STUTTER)*
- **F2.3** Split di `filteredAppsProvider` (visible+sorted memoizzato + derivato query). *(STUTTER, opzionale)*
- **F2.4** Decode icone **lazy** (`getAppIcon(packageName)` on-demand nei picker); test di parità set launchable. Inventario base label-only sempre cheap. *(RELOAD cold start + memoria)*
- **F2.5** Debounce/dedup del trigger achievements + `Future.wait`; rimuovere il drawer pull-to-refresh globale o renderlo mirato. *(RELOAD)*
- **F2.6** (Dopo S1) Ridurre la dipendenza dall'invalidate-su-resume ora che il canale è affidabile: tenerlo solo come fallback raro gateato.

### Fase 3 — Verifica con strumenti
- Attivare `PerfObserver` + counter resume/reload; confermare che il path launcher è no-op (Fase 1.5 efficace).
- DevTools Timeline + performance overlay con monochrome ON/OFF (decidere se S3 richiede intervento — solo dopo misura).
- Perfetto sul main thread durante burst `TYPE_WINDOWS_CHANGED`: confermare la sparizione degli slice Keystore (F1.1/F2.1).
- Log nativi durata `getInstalledPackageNames`/`getInstalledApps` post-offload.
- Regression test: drawer/favoriti non vuoti dopo throttle resume; recapito affidabile di `BLOCKING_STATE`/`PACKAGE_CHANGED` post-S1; suite `flutter test` + Kotlin verde prima del push (memoria `feedback_tests_green_before_push`).

---

### Appendice — Correzioni fattuali rilevanti emerse dall'audit
- Il `KoruAccessibilityService` gira nel **main process**, NON in `:accessibility` (`AndroidManifest.xml:79`; commenti interni stale). Questo **aggrava** F1 (compete col main thread UI), ma sblocca la cache della mask (invalidazione cross-process non necessaria).
- `todayMoodProvider` è un `FutureProvider`, non StreamProvider.
- `ListView(children:)` è lazy a livello di Element/layout/paint: l'inefficienza è la **riallocazione di widget+closure**, non l'elementizzazione di tutti i figli ogni frame.
- Con **Impeller** la color-matrix è uno shader GPU, non un saveLayer CPU offscreen per-frame.
