import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/theme/launcher_phase.dart';

/// Rail A-Z sul bordo destro del drawer. Tap/drag emette [onLetterSelected]
/// con haptic feedback; [onScrubEnd] segnala il dito alzato.
///
/// Lettere in `labelSmall` della type scale: quelle presenti in
/// `textPrimary`, le assenti quasi svanite. Quella sotto il dito cresce e
/// passa in accento — ed è l'unica che si muove.
///
/// Il feedback grande sta altrove: il chiamante disegna la pastiglia con la
/// lettera corrente accanto al rail (vedi `AllAppsScreen`).
class FastScroller extends StatefulWidget {
  const FastScroller({
    super.key,
    required this.onLetterSelected,
    required this.availableLetters,
    required this.phase,
    this.onScrubEnd,
  });

  final ValueChanged<String> onLetterSelected;
  final Set<String> availableLetters;
  final LauncherPhase phase;

  /// Chiamato quando il dito lascia il rail (o dopo un tap): il chiamante lo
  /// usa per far sparire la lettera fantasma.
  final VoidCallback? onScrubEnd;

  static const List<String> alphabet = [
    '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I',
    'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S',
    'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  @override
  State<FastScroller> createState() => _FastScrollerState();
}

class _FastScrollerState extends State<FastScroller> {
  String? _activeLetter;
  final GlobalKey _columnKey = GlobalKey();

  String? _letterAtPosition(double localY) {
    final renderBox = _columnKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final height = renderBox.size.height;
    final letterHeight = height / FastScroller.alphabet.length;
    final index = (localY / letterHeight)
        .floor()
        .clamp(0, FastScroller.alphabet.length - 1);
    return FastScroller.alphabet[index];
  }

  void _handleDrag(double localY) {
    final letter = _letterAtPosition(localY);
    if (letter != null && letter != _activeLetter) {
      setState(() => _activeLetter = letter);
      HapticFeedback.selectionClick();
      widget.onLetterSelected(letter);
    }
  }

  void _release() {
    setState(() => _activeLetter = null);
    widget.onScrubEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.phase;
    final base = Theme.of(context).textTheme.labelSmall;

    return GestureDetector(
      onVerticalDragStart: (d) => _handleDrag(d.localPosition.dy),
      onVerticalDragUpdate: (d) => _handleDrag(d.localPosition.dy),
      onVerticalDragEnd: (_) => _release(),
      onVerticalDragCancel: _release,
      onTapUp: (d) {
        _handleDrag(d.localPosition.dy);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _release();
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 42,
        child: Column(
          key: _columnKey,
          mainAxisAlignment: MainAxisAlignment.center,
          children: FastScroller.alphabet.map((letter) {
            final isActive = letter == _activeLetter;
            final isAvailable = widget.availableLetters.contains(letter);
            return Expanded(
              child: Center(
                child: AnimatedScale(
                  scale: isActive ? 1.8 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    letter,
                    style: base?.copyWith(
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? phase.accent
                          : (isAvailable
                              ? KoruColors.textPrimary
                              : KoruColors.textSecondary
                                  .withValues(alpha: 0.3)),
                    ),
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        ),
      ),
    );
  }
}
