import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../home/widgets/placeholder_tab_body.dart';

class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabFocus)),
      body: PlaceholderTabBody(
        icon: Icons.self_improvement_outlined,
        label: l10n.tabFocus,
        hint: 'Focus mode + Pomodoro + Quick Block (Step 10)',
      ),
    );
  }
}
