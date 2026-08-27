import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../domain/entities/unlock_challenge.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../providers/unlock_challenge_provider.dart';
import '../../../widgets/koru_pull_to_refresh.dart';
import '../../../widgets/unlock_challenge_dialog.dart';

/// Impostazioni della sfida di sblocco: quanto attrito mettere davanti alle
/// azioni che INDEBOLISCONO una protezione.
///
/// Alzare il livello è immediato; anche abbassarlo lo è — di proposito. Questa
/// non è la strict mode: non pretende di reggere contro te stesso determinato,
/// serve a spezzare l'automatismo del momento. Un lucchetto sul lucchetto
/// avrebbe solo spostato il problema di un tap.
/// Etichette tradotte dei livelli. Stanno qui e non sull'enum in `domain/`
/// perché sono testo di UI: il domain non importa Flutter e non può leggere
/// [AppLocalizations].
extension UnlockChallengeLevelL10n on UnlockChallengeLevel {
  String label(AppLocalizations l10n) => switch (this) {
        UnlockChallengeLevel.gentle => l10n.unlockChallengeLevelGentle,
        UnlockChallengeLevel.standard => l10n.unlockChallengeLevelStandard,
        UnlockChallengeLevel.stubborn => l10n.unlockChallengeLevelStubborn,
      };

  String description(AppLocalizations l10n) => switch (this) {
        UnlockChallengeLevel.gentle => l10n.unlockChallengeLevelGentleDesc,
        UnlockChallengeLevel.standard => l10n.unlockChallengeLevelStandardDesc,
        UnlockChallengeLevel.stubborn => l10n.unlockChallengeLevelStubbornDesc,
      };
}

class UnlockChallengeScreen extends ConsumerWidget {
  const UnlockChallengeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(unlockChallengeLevelProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.unlockChallengeTitle)),
      body: KoruPullToRefresh(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: KoruColors.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.psychology_outlined,
                        color: KoruColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.unlockChallengeActiveFriction(
                            level.label(l10n).toLowerCase(),
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.unlockChallengeExplainer,
                    style: const TextStyle(
                      color: KoruColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _SectionTitle(l10n.unlockChallengeHowMuchFriction),
            const SizedBox(height: 4),
            for (final option in UnlockChallengeLevel.values)
              _LevelTile(
                level: option,
                selected: option == level,
                onTap: () => ref
                    .read(unlockChallengeLevelProvider.notifier)
                    .setLevel(option),
              ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => _preview(context, ref),
              icon: const Icon(Icons.play_arrow_outlined),
              label: Text(l10n.unlockChallengeTryNow),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: KoruColors.primary,
                side: const BorderSide(color: KoruColors.outline),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.unlockChallengeTryNowNote,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: KoruColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _preview(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final passed = await requireUnlockChallenge(
      context,
      ref,
      action: l10n.unlockChallengeActionPreview,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          passed
              ? l10n.unlockChallengePreviewPassed
              : l10n.unlockChallengePreviewCancelled,
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final UnlockChallengeLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? KoruColors.primaryContainer : KoruColors.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected
                      ? KoruColors.onPrimaryContainer
                      : KoruColors.textSecondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level.label(l10n),
                        style: TextStyle(
                          color: selected
                              ? KoruColors.onPrimaryContainer
                              : KoruColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        level.description(l10n),
                        style: TextStyle(
                          color: selected
                              ? KoruColors.onPrimaryContainer.withAlpha(190)
                              : KoruColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: KoruColors.primary.withAlpha(220),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    ),
  );
}
