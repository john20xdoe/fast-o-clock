import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class TimerRing extends StatefulWidget {
  final double progress;
  final bool isActive;
  final bool isGoalMet;
  final bool isCountdown;
  final Widget child;
  final double size;
  final double strokeWidth;

  const TimerRing({
    super.key,
    required this.progress,
    required this.isActive,
    required this.isGoalMet,
    this.isCountdown = false,
    required this.child,
    this.size = 280,
    this.strokeWidth = 18,
  });

  @override
  State<TimerRing> createState() => _TimerRingState();
}

class _TimerRingState extends State<TimerRing> {
  static const Duration _frameInterval = Duration(milliseconds: 65);

  Timer? _emberTimer;
  final math.Random _rng = math.Random();
  double _currentEmber = 0.78;
  double _targetEmber = 0.85;
  int _lastHopMs = 0;
  int _nextHopMs = 90;

  bool get _shouldAnimateEmber => widget.isActive && !widget.isGoalMet;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  void _syncTimer() {
    if (_shouldAnimateEmber) {
      _emberTimer ??= Timer.periodic(_frameInterval, (_) => _stepEmberFlicker());
    } else {
      _emberTimer?.cancel();
      _emberTimer = null;
    }
  }

  void _stepEmberFlicker() {
    if (!mounted) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastHopMs == 0) {
      _lastHopMs = nowMs;
    } else if (nowMs - _lastHopMs >= _nextHopMs) {
      _lastHopMs = nowMs;
      _nextHopMs = 65 + _rng.nextInt(135); // 65-200ms irregular cadence
      final roll = _rng.nextDouble();
      if (roll < 0.14) {
        // Occasional dim dip
        _targetEmber = 0.38 + _rng.nextDouble() * 0.18;
      } else if (roll > 0.82) {
        // Occasional bright flare
        _targetEmber = 0.90 + _rng.nextDouble() * 0.10;
      } else {
        _targetEmber = 0.58 + _rng.nextDouble() * 0.32;
      }
    }
    setState(() {
      _currentEmber += (_targetEmber - _currentEmber) * 0.24;
    });
  }

  @override
  void didUpdateWidget(covariant TimerRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldAnimateEmber && _emberTimer == null) {
      _lastHopMs = 0;
    }
    _syncTimer();
  }

  @override
  void dispose() {
    _emberTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final emberIntensity = _shouldAnimateEmber
        ? (disableAnimations ? 0.80 : _currentEmber)
        : 0.0;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _TimerRingPainter(
          progress: widget.progress.clamp(0.0, 1.0),
          isActive: widget.isActive,
          isGoalMet: widget.isGoalMet,
          isCountdown: widget.isCountdown,
          emberIntensity: emberIntensity,
          trackColor: trackColor,
          strokeWidth: widget.strokeWidth,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(widget.strokeWidth * 1.8),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  final double progress;
  final bool isActive;
  final bool isGoalMet;
  final bool isCountdown;
  final double emberIntensity;
  final Color trackColor;
  final double strokeWidth;

  _TimerRingPainter({
    required this.progress,
    required this.isActive,
    required this.isGoalMet,
    required this.isCountdown,
    required this.emberIntensity,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (!isActive) return;

    final displayedRatio = isCountdown ? (1.0 - progress) : progress;
    if (displayedRatio <= 0.0 && !isGoalMet) return;

    const topAngle = -math.pi / 2;
    final startAngle =
        isCountdown ? topAngle + (2 * math.pi * progress) : topAngle;
    final sweepAngle =
        2 * math.pi * (isGoalMet && isCountdown ? 0.0 : displayedRatio);

    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (isGoalMet) {
      arcPaint.color = const Color(0xFF00C853);
      if (isCountdown) return;
    } else {
      final colors = isCountdown
          ? const [Color(0xFFFF5252), Color(0xFFFF8A00), Color(0xFFFF5252)]
          : const [Color(0xFFFF8A00), Color(0xFFFF5252), Color(0xFFFF8A00)];
      arcPaint.shader = SweepGradient(
        startAngle: 0.0,
        endAngle: 2 * math.pi,
        colors: colors,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    }

    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);

    if (!isGoalMet && emberIntensity > 0.0) {
      final emberAngle =
          isCountdown ? startAngle : topAngle + sweepAngle;
      final emberCenter = Offset(
        center.dx + math.cos(emberAngle) * radius,
        center.dy + math.sin(emberAngle) * radius,
      );

      // 1. Larger, brighter atmospheric ember bloom
      final bloomRadius = strokeWidth * (1.25 + 0.30 * emberIntensity);
      canvas.drawCircle(
        emberCenter,
        bloomRadius,
        Paint()
          ..color = const Color(0xFFFF6D00)
              .withValues(alpha: 0.62 * emberIntensity)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            12 + 7 * emberIntensity,
          ),
      );
      canvas.drawCircle(
        emberCenter,
        strokeWidth * (0.85 + 0.18 * emberIntensity),
        Paint()
          ..color = const Color(0xFFFFAB40)
              .withValues(alpha: 0.78 * emberIntensity)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            6 + 3 * emberIntensity,
          ),
      );

      // 2. Full-cap radial blend: fills entire rounded end of fg track,
      // glowing near-white across the cap and fading into the fg track color.
      final capRadius = strokeWidth * 0.54;
      final capRect = Rect.fromCircle(center: emberCenter, radius: capRadius);
      final fgEdgeColor =
          isCountdown ? const Color(0xFFFF5252) : const Color(0xFFFF8A00);
      canvas.drawCircle(
        emberCenter,
        capRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.lerp(
                const Color(0xFFFFE8C8),
                const Color(0xFFFFFFFF),
                emberIntensity,
              )!,
              const Color(0xFFFFCC80)
                  .withValues(alpha: 0.78 + 0.22 * emberIntensity),
              fgEdgeColor.withValues(alpha: 0.85 * emberIntensity),
              fgEdgeColor.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.55, 0.86, 1.0],
          ).createShader(capRect),
      );

      // 3. Broad incandescent almost-white core filling most of the cap
      canvas.drawCircle(
        emberCenter,
        strokeWidth * (0.34 + 0.06 * emberIntensity),
        Paint()
          ..color = const Color(0xFFFFFDF9)
              .withValues(alpha: 0.72 + 0.28 * emberIntensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isActive != isActive ||
        oldDelegate.isGoalMet != isGoalMet ||
        oldDelegate.isCountdown != isCountdown ||
        oldDelegate.emberIntensity != emberIntensity ||
        oldDelegate.trackColor != trackColor;
  }
}
