import 'package:flutter/material.dart';

import '../../../../core/constants/koru_colors.dart';

/// Prominent pre-permission disclosure — pagina 2/5 dell'onboarding, PRIMA
/// della pagina Permissions.
///
/// Spiega onestamente come Koru usa i permessi sensibili prima di richiederli:
/// è un requisito di policy Play per un'app NON-tool che usa l'Accessibility
/// (Koru non dichiara isAccessibilityTool) ed è una leva di conversione oltre
/// il "muro permessi". Coerente con SECURITY.md: Strict Mode è un deterrente
/// (non un lock) e l'enforcement degrada se l'Accessibility viene revocata.
class PrePermissionDisclosurePage extends StatelessWidget {
  const PrePermissionDisclosurePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How Koru uses permissions',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Read this before granting — no surprises.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: KoruColors.textSecondary,
                ),
          ),
          const SizedBox(height: 24),
          const _Point(
            icon: Icons.phonelink_lock,
            title: 'On-device only',
            body: 'No account, no telemetry, no ads. Nothing you do in Koru '
                'ever leaves your phone.',
          ),
          const _Point(
            icon: Icons.accessibility_new,
            title: 'Accessibility',
            body: 'Koru reads which app or website is in the foreground so it '
                'can block it. On Android this is the only way to enforce '
                'blocking — Koru is not an accessibility tool and uses it for '
                'nothing else.',
          ),
          const _Point(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Device Admin (optional)',
            body: 'Used only for Strict Mode, and only if you turn it on. It '
                'makes uninstalling Koru harder — a deterrent, not an '
                'unbreakable lock.',
          ),
          const _Point(
            icon: Icons.tune,
            title: 'You stay in control',
            body: 'Revoke any permission anytime. If Accessibility is off, '
                'blocking degrades to app-level only — Koru tells you what is '
                'paused.',
          ),
          const _Point(
            icon: Icons.code,
            title: 'Open source',
            body: 'Audit exactly what Koru does — the full source is at '
                'github.com/predamatteo/koru.',
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: KoruColors.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KoruColors.textSecondary,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
