import 'package:flutter/material.dart';

import '../../../../core/constants/koru_colors.dart';

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
            'A Maori symbol of inner growth.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: KoruColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Koru is a minimalist launcher and a mindful blocker. '
            'It helps you take back your attention — one breath at a time.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
