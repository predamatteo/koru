import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'presentation/providers/achievement_evaluator.dart';
import 'presentation/providers/events_refresher.dart';
import 'presentation/providers/home_intent_listener.dart';
import 'presentation/providers/monochrome_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/widgets/achievement_unlock_listener.dart';

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
    ref.watch(achievementEvaluatorProvider);
    final monochrome = ref.watch(monochromeProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      theme: AppTheme.dark(fontFamily: font.family),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        Widget content = AchievementUnlockListener(
          child: child ?? const SizedBox.shrink(),
        );
        if (monochrome) {
          content = ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0, 0, 0, 1, 0,
            ]),
            child: content,
          );
        }
        return content;
      },
    );
  }
}
