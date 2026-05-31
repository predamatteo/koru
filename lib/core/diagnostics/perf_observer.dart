import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Diagnostica di performance (Fase 3) — montata in [main] SOLO in debug
/// (`kDebugMode`), quindi zero overhead in profile/release.
///
/// Logga ogni ricomputo (`didUpdateProvider`) e dispose di provider con nome e
/// timestamp, sul tag `KoruPerf.provider`. Serve a "leggere" quante e quali
/// invalidazioni partono davvero — in particolare:
///  - quante per ogni `resumed` del launcher (deve avvicinarsi a zero dopo il
///    throttle di F1.5/F2.6 — correlare col tag `KoruPerf.resume`);
///  - se un provider torna a ricaricarsi senza motivo (spia di regressione).
///
/// Lettura on-device: `adb logcat -s flutter` e filtra `KoruPerf`.
class PerfObserver extends ProviderObserver {
  const PerfObserver();

  String _name(ProviderBase<Object?> provider) =>
      provider.name ?? provider.runtimeType.toString();

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    developer.log('[update] ${_name(provider)}', name: 'KoruPerf.provider');
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    developer.log('[dispose] ${_name(provider)}', name: 'KoruPerf.provider');
  }
}
