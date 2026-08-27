import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_locale.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../providers/locale_provider.dart';
import '../../../widgets/koru_pull_to_refresh.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(localePreferenceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageTitle)),
      body: KoruPullToRefresh(
        child: RadioGroup<KoruLocale>(
          groupValue: current,
          onChanged: (l) {
            if (l != null) ref.read(localePreferenceProvider.notifier).set(l);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              for (final locale in KoruLocale.values)
                RadioListTile<KoruLocale>(
                  value: locale,
                  title: Text(_label(locale, l10n)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Text(
                  l10n.languageNativeNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// I nomi delle lingue restano nella lingua stessa (endonimi): chi apre
  /// questa schermata per uscire da una lingua che non legge deve comunque
  /// riconoscere la propria. Solo "predefinita di sistema" si traduce, perché
  /// non è il nome di una lingua ma una descrizione.
  String _label(KoruLocale locale, AppLocalizations l10n) => switch (locale) {
        KoruLocale.system => l10n.languageSystemDefault,
        KoruLocale.italian => 'Italiano',
        KoruLocale.english => 'English',
      };
}
