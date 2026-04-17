import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/hive_keys.dart';
import '../../../core/constants/koru_colors.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import 'pages/launcher_page.dart';
import 'pages/permissions_page.dart';
import 'pages/presets_page.dart';
import 'pages/welcome_page.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= 3) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _finish() async {
    final hive = ref.read(hiveSettingsServiceProvider);
    await hive.put(HiveKeys.onboardingBox, HiveKeys.isOnboardingPassed, true);
    if (mounted) context.go(KoruRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (p) => setState(() => _page = p),
                children: const [
                  WelcomePage(),
                  PermissionsPage(),
                  PresetsPage(),
                  LauncherPage(),
                ],
              ),
            ),
            _PageIndicator(current: _page, total: 4),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_page == 3 ? 'Enter Koru' : 'Continue'),
                ),
              ),
            ),
            if (_page < 3)
              TextButton(
                onPressed: _finish,
                child: const Text('Skip for now'),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: active ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active ? KoruColors.primary : KoruColors.textSecondary,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
