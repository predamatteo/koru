import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../home/widgets/placeholder_tab_body.dart';

class ProfilesListScreen extends StatelessWidget {
  const ProfilesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabProfiles)),
      body: PlaceholderTabBody(
        icon: Icons.shield_outlined,
        label: l10n.tabProfiles,
        hint: 'Profili di blocco: creazione, edit, attivazione automatica (Step 8-9)',
      ),
    );
  }
}
