import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'presentation/providers/events_refresher.dart';
import 'presentation/providers/home_intent_listener.dart';
import 'presentation/providers/theme_provider.dart';

class KoruApp extends ConsumerWidget {
  const KoruApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final font = ref.watch(fontPreferenceProvider);
    // Active-in-root per tutta la durata dell'app: invalida stats/profiles
    // ogni volta che l'app torna in foreground (no eventi persi durante bg).
    ref.watch(appLifecycleInvalidatorProvider);
    ref.watch(blockingEventsRefresherProvider);
    ref.watch(homeIntentListenerProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      theme: AppTheme.dark(fontFamily: font.family),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
