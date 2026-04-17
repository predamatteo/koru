import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../providers/battery_provider.dart';

/// Circolo con anello batteria + orologio + data al centro.
///
/// L'anello rappresenta il livello batteria come arco da mezzogiorno in senso
/// orario. Durante la ricarica, un pulse leggero anima l'opacità dell'arco e
/// lo sweep parte da 0 → livello corrente.
class CircleClockWidget extends ConsumerStatefulWidget {
  const CircleClockWidget({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  ConsumerState<CircleClockWidget> createState() => _CircleClockWidgetState();
}

class _CircleClockWidgetState extends ConsumerState<CircleClockWidget>
    with SingleTickerProviderStateMixin {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  late final AnimationController _chargeAnimController;
  late Animation<double> _sweepAnimation;
  late Animation<double> _pulseAnimation;
  bool _wasCharging = false;

  static final DateFormat _timeFormat = DateFormat.Hm();
  static final DateFormat _dateFormat = DateFormat('EEE, d MMM');

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _chargeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _sweepAnimation = const AlwaysStoppedAnimation<double>(1.0);
    _pulseAnimation = const AlwaysStoppedAnimation<double>(1.0);
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _chargeAnimController.dispose();
    super.dispose();
  }

  void _startChargeAnimation(double batteryFraction) {
    _chargeAnimController
      ..stop()
      ..reset();
    final durationMs = (2000 * batteryFraction).clamp(400, 2000).toInt();
    _chargeAnimController.duration = Duration(milliseconds: durationMs);
    _sweepAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _chargeAnimController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _pulseAnimation = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _chargeAnimController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );
    _chargeAnimController.repeat(reverse: true);
  }

  void _stopChargeAnimation() {
    _chargeAnimController.stop();
    _sweepAnimation = const AlwaysStoppedAnimation<double>(1.0);
    _pulseAnimation = const AlwaysStoppedAnimation<double>(1.0);
  }

  @override
  Widget build(BuildContext context) {
    final batteryLevel = ref.watch(batteryLevelProvider).valueOrNull ?? 0;
    final isCharging = ref.watch(isChargingProvider).valueOrNull ?? false;
    final batteryFraction = (batteryLevel / 100).clamp(0.0, 1.0);

    if (isCharging && !_wasCharging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startChargeAnimation(batteryFraction);
      });
    } else if (!isCharging && _wasCharging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _stopChargeAnimation();
      });
    }
    _wasCharging = isCharging;

    final theme = Theme.of(context);
    final foreground = theme.textTheme.bodyMedium?.color ?? KoruColors.textPrimary;
    final timeString = _timeFormat.format(_now);
    final dateString = _dateFormat.format(_now);

    return SizedBox(
      width: 200,
      height: 200,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _chargeAnimController,
          builder: (context, child) {
            final effectiveFraction = isCharging
                ? batteryFraction * _sweepAnimation.value
                : batteryFraction;
            final arcOpacity = isCharging ? _pulseAnimation.value : 1.0;
            return CustomPaint(
              painter: _BatteryArcPainter(
                batteryFraction: effectiveFraction,
                arcColor: foreground,
                strokeWidth: 2.0,
                arcOpacity: arcOpacity,
              ),
              child: child,
            );
          },
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 140,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      timeString,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w200,
                        letterSpacing: 4,
                        color: foreground,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 160,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      dateString,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground.withAlpha(180),
                        letterSpacing: 1,
                      ),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
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

class _BatteryArcPainter extends CustomPainter {
  _BatteryArcPainter({
    required this.batteryFraction,
    required this.arcColor,
    required this.strokeWidth,
    this.arcOpacity = 1.0,
  })  : _bgPaint = Paint()
          ..color = arcColor.withAlpha(38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
        _fgPaint = Paint()
          ..color = arcColor.withAlpha((255 * arcOpacity).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

  final double batteryFraction;
  final Color arcColor;
  final double strokeWidth;
  final double arcOpacity;

  final Paint _bgPaint;
  final Paint _fgPaint;

  static const double _startAngle = -pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2) - (strokeWidth / 2);
    canvas.drawCircle(center, radius, _bgPaint);
    if (batteryFraction > 0) {
      final sweepAngle = batteryFraction * 2 * pi;
      final arcRect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(arcRect, _startAngle, sweepAngle, false, _fgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BatteryArcPainter oldDelegate) =>
      oldDelegate.batteryFraction != batteryFraction ||
      oldDelegate.arcColor != arcColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.arcOpacity != arcOpacity;
}
