import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';

class LauncherPage extends ConsumerWidget {
  const LauncherPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.home_outlined, size: 64, color: KoruColors.primary),
          const SizedBox(height: 24),
          Text('Use Koru as your launcher',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            'Set Koru as your default home screen for the full minimalist '
            'experience. You can always change this later in Settings.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: KoruColors.textSecondary,
                ),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () =>
                ref.read(platformChannelServiceProvider).permission.openDefaultLauncherSettings(),
            child: const Text('Set Koru as default launcher'),
          ),
          const SizedBox(height: 8),
          Text(
            'Or skip — Koru works great either way.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: KoruColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
