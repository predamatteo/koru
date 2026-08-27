import 'package:flutter/material.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Koru',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontFamily: 'Orbitron',
                  letterSpacing: 8,
                ),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context).onboardingWelcomeTagline,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: KoruColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).onboardingWelcomeBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
