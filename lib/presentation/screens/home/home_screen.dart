import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../core/router/app_router.dart';
import 'widgets/circle_clock_widget.dart';
import 'widgets/favorites_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            const CircleClockWidget(),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    FavoritesList(),
                  ],
                ),
              ),
            ),
            _AllAppsButton(
              onPressed: () => context.push(KoruRoutes.drawer),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _AllAppsButton extends StatelessWidget {
  const _AllAppsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.apps_outlined, color: KoruColors.textSecondary),
      label: const Text(
        'All apps',
        style: TextStyle(color: KoruColors.textSecondary, letterSpacing: 1),
      ),
    );
  }
}
