import 'package:flutter/material.dart';

import '../../../../core/constants/koru_colors.dart';

/// Prompt mindful che appare sopra la countdown nel BlockOverlayScreen.
/// Permette all'utente di articolare intenzione prima di aprire un'app bloccata.
/// L'intenzione scelta viene registrata in [intentions] table per analytics.
class MindfulIntentionPrompt extends StatefulWidget {
  const MindfulIntentionPrompt({
    super.key,
    required this.suggestions,
    this.onIntentionChosen,
  });

  final List<String> suggestions;
  final ValueChanged<String>? onIntentionChosen;

  @override
  State<MindfulIntentionPrompt> createState() => _MindfulIntentionPromptState();
}

class _MindfulIntentionPromptState extends State<MindfulIntentionPrompt> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Why are you opening it?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: KoruColors.textPrimary.withValues(alpha: 0.85),
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: widget.suggestions
              .map(
                (text) => ChoiceChip(
                  label: Text(text),
                  selected: _selected == text,
                  onSelected: (_) {
                    setState(() => _selected = text);
                    widget.onIntentionChosen?.call(text);
                  },
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
