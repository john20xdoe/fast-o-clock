import 'dart:math' as math;

import 'package:flutter/material.dart';

class TimerRing extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TimerRingPainter(
          progress: progress.clamp(0.0, 1.0),
          isActive: isActive,
          isGoalMet: isGoalMet,
          isCountdown: isCountdown,
          trackColor: trackColor,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(strokeWidth * 1.8),
            child: child,
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
  final Color trackColor;
  final double strokeWidth;

  _TimerRingPainter({
    required this.progress,
    required this.isActive,
    required this.isGoalMet,
    required this.isCountdown,
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
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isActive != isActive ||
        oldDelegate.isGoalMet != isGoalMet ||
        oldDelegate.isCountdown != isCountdown ||
        oldDelegate.trackColor != trackColor;
  }
}
