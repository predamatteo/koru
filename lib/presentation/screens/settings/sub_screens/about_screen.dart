import 'package:flutter/material.dart';

import '../../../../core/constants/koru_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
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
          Text(
            'Koru',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'The Koru is the unfolding frond of a silver fern, a sacred Maori '
            'symbol of new life and inner growth. It reminds us that focus is '
            'not a constraint — it is a returning to ourselves.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 32),
          Text(
            'Privacy',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Everything Koru does happens on your device. No accounts, no ads, '
            'no tracking. Ever.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
