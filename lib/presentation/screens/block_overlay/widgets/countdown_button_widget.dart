import 'package:flutter/material.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../domain/entities/countdown_state.dart';

/// Custom animated countdown button that fills left-to-right.
///
/// State machine: INITIALIZED -> ANIMATING <-> PAUSED -> FINISHED
/// - Auto-starts on mount (postFrame).
/// - Tap while animating: pause. Tap while paused: resume.
/// - When complete, shows [finishedText] and subsequent taps invoke [onTap].
class CountdownButtonWidget extends StatefulWidget {
  const CountdownButtonWidget({
    super.key,
    this.durationMs = 8000,
    this.fillColor = KoruColors.primary,
    this.textColor = KoruColors.textPrimary,
    this.backgroundColor = const Color(0x33FFFFFF),
    this.finishedText = 'Open',
    this.onFinished,
    this.onTap,
    this.borderRadius = 16.0,
  });

  final int durationMs;
  final Color fillColor;
  final Color textColor;
  final Color backgroundColor;
  final String finishedText;
  final VoidCallback? onFinished;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  State<CountdownButtonWidget> createState() => _CountdownButtonWidgetState();
}

class _CountdownButtonWidgetState extends State<CountdownButtonWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  CountdownPhase _phase = CountdownPhase.initialized;

  int get _remainingSeconds {
    final total = widget.durationMs / 1000;
    return ((1.0 - _controller.value) * total).ceil().clamp(0, total.ceil());
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationMs),
    );
    _controller.addStatusListener(_onAnimationStatus);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onAnimationStatus)
      ..dispose();
    super.dispose();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() => _phase = CountdownPhase.finished);
      widget.onFinished?.call();
    }
  }

  void _start() {
    setState(() => _phase = CountdownPhase.animating);
    _controller.forward();
  }

  void _handleTap() {
    switch (_phase) {
      case CountdownPhase.animating:
        _controller.stop();
        setState(() => _phase = CountdownPhase.paused);
      case CountdownPhase.paused:
        setState(() => _phase = CountdownPhase.animating);
        _controller.forward();
      case CountdownPhase.finished:
        widget.onTap?.call();
      case CountdownPhase.initialized:
        _start();
    }
  }

  String get _displayText => switch (_phase) {
        CountdownPhase.finished => widget.finishedText,
        CountdownPhase.paused => 'Paused',
        _ => '$_remainingSeconds',
      };

  Key get _textKey => ValueKey(switch (_phase) {
        CountdownPhase.finished => 'finished',
        CountdownPhase.paused => 'paused',
        _ => '$_remainingSeconds',
      });

  double get _fontSize => _phase == CountdownPhase.finished ? 18.0 : 28.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _phase == CountdownPhase.finished
          ? widget.finishedText
          : 'Countdown: $_remainingSeconds seconds remaining',
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Container(
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(widget.borderRadius),
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: _controller.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.fillColor,
                        borderRadius:
                            BorderRadius.circular(widget.borderRadius),
                      ),
                    ),
                  ),
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Text(
                        _displayText,
                        key: _textKey,
                        style: TextStyle(
                          color: widget.textColor,
                          fontSize: _fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
