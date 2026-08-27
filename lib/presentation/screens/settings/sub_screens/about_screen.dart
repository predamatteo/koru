import 'package:flutter/material.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../widgets/koru_pull_to_refresh.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: KoruPullToRefresh(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            // Il wordmark resta "Koru" in ogni lingua: è il nome del prodotto,
            // non una stringa di UI (stesso motivo per cui `app_name` è
            // translatable="false" in strings.xml).
            const Center(
              child: Text(
                'Koru',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 48,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                '0.1.0 · com.dev.koru',
                style: TextStyle(color: KoruColors.textSecondary),
              ),
            ),
            const SizedBox(height: 32),
            Text(l10n.appName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.aboutKoruBody,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.aboutPrivacyTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.aboutPrivacyBody,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
