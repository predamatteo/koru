import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/koru_colors.dart';
import '../../../domain/entities/overlay_config.dart';
import '../../providers/intention_provider.dart';
import 'overlay_config_style.dart';
import 'widgets/countdown_button_widget.dart';
import 'widgets/mindful_intention_prompt.dart';

/// Full-screen Flutter blocking overlay.
///
/// Usato in due casi:
/// 1) Preview/demo dentro l'app (Settings → Overlay Designer, onboarding).
/// 2) Lanciato dal native via deep-link `/block-overlay/:pkg` quando si
///    vuole un'esperienza più ricca (intention prompt) dell'overlay Compose
///    di OverlayManager.
///
/// L'overlay Compose di `service/OverlayManager.kt` è la default istantanea.
class BlockOverlayScreen extends ConsumerStatefulWidget {
  const BlockOverlayScreen({
    super.key,
    required this.packageName,
    required this.appLabel,
    this.config = OverlayConfig.defaults,
    this.reason = BlockReason.appBlocked,
    this.sectionName,
    this.blockedDomain,
    this.profileTitle,
    this.intentionSuggestions = const [
      'Reply to a message',
      'Check one thing',
      'Just scroll',
      'Not sure',
    ],
    this.onGoHome,
    this.onContinue,
  });

  final String packageName;
  final String appLabel;
  final OverlayConfig config;
  final BlockReason reason;
  final String? sectionName;
  final String? blockedDomain;
  final String? profileTitle;
  final List<String> intentionSuggestions;
  final VoidCallback? onGoHome;
  final VoidCallback? onContinue;

  @override
  ConsumerState<BlockOverlayScreen> createState() =>
      _BlockOverlayScreenState();
}

enum BlockReason { appBlocked, focusMode, sectionBlocked, websiteBlocked }

class _BlockOverlayScreenState extends ConsumerState<BlockOverlayScreen> {
  bool _countdownFinished = false;
  String? _chosenIntention;

  String get _title => switch (widget.reason) {
        BlockReason.focusMode => 'Focus mode is active',
        BlockReason.sectionBlocked => 'Section blocked',
        BlockReason.websiteBlocked => 'Website blocked',
        BlockReason.appBlocked =>
          widget.config.messageTitle ?? 'Take a breath',
      };

  String get _subtitle {
    if (widget.sectionName != null) return widget.sectionName!;
    if (widget.blockedDomain != null) return widget.blockedDomain!;
    if (widget.profileTitle != null) {
      return 'Paused by \u201C${widget.profileTitle}\u201D';
    }
    return widget.appLabel;
  }

  IconData get _headerIcon => switch (widget.reason) {
        BlockReason.focusMode => Icons.self_improvement,
        BlockReason.sectionBlocked => Icons.layers_clear_outlined,
        BlockReason.websiteBlocked => Icons.language,
        BlockReason.appBlocked => Icons.spa_outlined,
      };

  void _recordIntentionAndContinue() {
    if (_chosenIntention != null) {
      ref.read(intentionRecorderProvider).record(
            packageName: widget.packageName,
            intention: _chosenIntention!,
          );
    }
    widget.onContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.config.backgroundColor;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [bg.withValues(alpha: 0.95), KoruColors.backgroundBase],
    );

    return Scaffold(
      backgroundColor: KoruColors.backgroundBase,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Soft sage halo around the mindful icon (design "A · Breath").
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: KoruColors.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(_headerIcon, size: 38, color: KoruColors.primary),
                ),
                const SizedBox(height: 22),
                Text(
                  _title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: KoruColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: KoruColors.textPrimary.withValues(alpha: 0.72),
                      ),
                  textAlign: TextAlign.center,
                ),
                if (widget.reason == BlockReason.appBlocked) ...[
                  const SizedBox(height: 32),
                  MindfulIntentionPrompt(
                    suggestions: widget.intentionSuggestions,
                    onIntentionChosen: (intention) =>
                        setState(() => _chosenIntention = intention),
                  ),
                ],
                const Spacer(flex: 2),
                // Recommended action first: stay away (bright sage primary).
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.onGoHome,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                    ),
                    child: Text("Don't open ${widget.appLabel}"),
                  ),
                ),
                const SizedBox(height: 12),
                // Bypass kept deliberately understated below the primary action.
                CountdownButtonWidget(
                  durationMs: widget.config.countdownSeconds * 1000,
                  fillColor: KoruColors.primary.withValues(alpha: 0.22),
                  textColor: KoruColors.primary,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  finishedText: 'Open ${widget.appLabel}',
                  onFinished: () =>
                      setState(() => _countdownFinished = true),
                  onTap: _countdownFinished && widget.config.allowBypassAfterCountdown
                      ? _recordIntentionAndContinue
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap the timer to pause it',
                  style: TextStyle(
                    color: KoruColors.textPrimary.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
