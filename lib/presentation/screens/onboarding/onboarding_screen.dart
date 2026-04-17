import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';

/// Placeholder per l'onboarding — verrà rimpiazzato in Step 13
/// con il wizard completo (permessi + preset + launcher opt-in).
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Onboarding placeholder', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(KoruRoutes.home),
              child: const Text('Continua'),
            ),
          ],
        ),
      ),
    );
  }
}
