import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/hive_keys.dart';
import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../l10n/generated/app_localizations.dart';

class LauncherPage extends ConsumerWidget {
  const LauncherPage({super.key});

  /// Apre le impostazioni di sistema per scegliere il launcher di default.
  ///
  /// Marca l'onboarding come completato PRIMA di aprire il dialog: quando
  /// l'utente seleziona Koru, Android riavvia l'app da zero lanciandola via
  /// HOME intent. Se `isOnboardingPassed` non fosse già `true`, al cold start
  /// il redirect del router rimanderebbe a `/onboarding` facendo ripartire
  /// tutto il flusso anche se permessi e step sono già fatti.
  Future<void> _setAsDefaultLauncher(WidgetRef ref) async {
    final hive = ref.read(hiveSettingsServiceProvider);
    await hive.put(HiveKeys.onboardingBox, HiveKeys.isOnboardingPassed, true);
    await ref
        .read(platformChannelServiceProvider)
        .permission
        .openDefaultLauncherSettings();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.home_outlined, size: 64, color: KoruColors.primary),
          const SizedBox(height: 24),
          Text(AppLocalizations.of(context).onboardingLauncherTitle,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).onboardingLauncherBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: KoruColors.textSecondary,
                ),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => _setAsDefaultLauncher(ref),
            child: Text(AppLocalizations.of(context).onboardingLauncherCta),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).onboardingLauncherSkipHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: KoruColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
