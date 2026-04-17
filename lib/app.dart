import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koru/core/theme/app_theme.dart';
import 'package:koru/l10n/generated/app_localizations.dart';

class KoruApp extends ConsumerWidget {
  const KoruApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _BootstrapHome(),
    );
  }
}

class _BootstrapHome extends StatelessWidget {
  const _BootstrapHome();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.appName,
                  style: textTheme.displayMedium?.copyWith(
                    fontFamily: 'Orbitron',
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.appTagline,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
