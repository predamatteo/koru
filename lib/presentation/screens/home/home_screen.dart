import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'widgets/placeholder_tab_body.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabHome)),
      body: PlaceholderTabBody(
        icon: Icons.home_outlined,
        label: l10n.tabHome,
        hint: 'Launcher home: clock + favorites + drawer (Step 7)',
      ),
    );
  }
}
