import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/l10n/generated/app_localizations.dart';

/// Pompa [widget] in un MaterialApp con ProviderScope + i delegate
/// AppLocalizations, e fa un `pumpAndSettle()`.
///
/// Uso tipico:
/// ```dart
/// await pumpKoruWidget(
///   tester,
///   const MyWidget(),
///   overrides: [...],
/// );
/// ```
///
/// Se il widget contiene animazioni infinite (es. orologio che fa tick) usa
/// [pumpKoruWidgetNoSettle] e poi `tester.pump(Duration(...))` manualmente.
Future<void> pumpKoruWidget(
  WidgetTester tester,
  Widget widget, {
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: widget),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Variante senza pumpAndSettle finale — per widget con animazioni
/// infinite (timer ricorrenti, orologi, fading loops).
Future<void> pumpKoruWidgetNoSettle(
  WidgetTester tester,
  Widget widget, {
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: widget),
      ),
    ),
  );
  // Un solo pump per montare il widget tree, NO settle.
  await tester.pump();
}
