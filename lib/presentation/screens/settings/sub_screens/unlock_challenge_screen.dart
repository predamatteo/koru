import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../domain/entities/unlock_challenge.dart';
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
class UnlockChallengeScreen extends ConsumerWidget {
  const UnlockChallengeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(unlockChallengeLevelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sfida di sblocco')),
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
                      Icon(
                        level.isActive
                            ? Icons.psychology_outlined
                            : Icons.bolt_outlined,
                        color: level.isActive
                            ? KoruColors.primary
                            : KoruColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          level.isActive
                              ? 'Attrito attivo: ${level.label.toLowerCase()}'
                              : 'Nessun attrito',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Spegnere un profilo, cancellarlo o togliergli app '
                    'richiede prima di memorizzare una breve sequenza di '
                    'simboli e di ricostruirla in una griglia piena di sosia.\n\n'
                    'Serve a mettere qualche secondo di lucidità fra '
                    'l\'impulso e il tap. Attivare una protezione resta '
                    'sempre immediato.',
                    style: TextStyle(
                      color: KoruColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _SectionTitle('Quanto attrito'),
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
              onPressed: level.isActive
                  ? () => _preview(context, ref)
                  : null,
              icon: const Icon(Icons.play_arrow_outlined),
              label: const Text('Provala adesso'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: KoruColors.primary,
                side: const BorderSide(color: KoruColors.outline),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              level.isActive
                  ? 'Una prova a vuoto: non disattiva niente.'
                  : 'Scegli un livello per poterla provare.',
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
    final passed = await requireUnlockChallenge(
      context,
      ref,
      action: 'provare la sfida',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          passed
              ? 'Superata. È esattamente questo che ti verrà chiesto.'
              : 'Prova annullata.',
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
                        level.label,
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
                        level.description,
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
