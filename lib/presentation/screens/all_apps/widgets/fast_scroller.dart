import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Strip A-Z verticale. Tap/drag emette [onLetterSelected] con haptic feedback.
class FastScroller extends StatefulWidget {
  const FastScroller({
    super.key,
    required this.onLetterSelected,
    required this.availableLetters,
  });

  final ValueChanged<String> onLetterSelected;
  final Set<String> availableLetters;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.iconTheme.color ?? Colors.white;

    return GestureDetector(
      onVerticalDragStart: (d) => _handleDrag(d.localPosition.dy),
      onVerticalDragUpdate: (d) => _handleDrag(d.localPosition.dy),
      onVerticalDragEnd: (_) => setState(() => _activeLetter = null),
      onVerticalDragCancel: () => setState(() => _activeLetter = null),
      onTapUp: (d) {
        _handleDrag(d.localPosition.dy);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _activeLetter = null);
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
                  scale: isActive ? 1.5 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isAvailable
                          ? (isActive ? textColor : textColor.withAlpha(180))
                          : textColor.withAlpha(60),
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
