import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../home/widgets/placeholder_tab_body.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabStats)),
      body: PlaceholderTabBody(
        icon: Icons.insights_outlined,
        label: l10n.tabStats,
        hint: 'Dashboard stats + mood check-in (Step 12)',
      ),
    );
  }
}
