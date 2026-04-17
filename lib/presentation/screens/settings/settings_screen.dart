import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../home/widgets/placeholder_tab_body.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSettings)),
      body: PlaceholderTabBody(
        icon: Icons.settings_outlined,
        label: l10n.tabSettings,
        hint: 'Temi, lingua, launcher, strict mode, about (Step 14)',
      ),
    );
  }
}
