import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated launch splash showing the stylized Fast O'Clock countdown icon
/// rotating its hands and countdown wedge cleanly to zero (12 o'clock).
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onFinished,
    this.duration = const Duration(milliseconds: 1250),
  });

  final VoidCallback onFinished;
  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  late final Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _progress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 0.82, curve: Curves.easeOutCubic),
    );

    _fadeOut = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.82, 1.0, curve: Curves.easeInOut),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onFinished();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121417),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Opacity(
            opacity: 1.0 - _fadeOut.value,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CustomPaint(
                      painter: TimelapseIconPainter(progress: _progress.value),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Fast O'Clock",
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontVariations: [FontVariation.weight(800)],
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// CustomPainter for the stylized timelapse countdown icon.
///
/// As [progress] animates from `0.0` to `1.0`, the remaining countdown arc/wedge
/// sweeps to zero and both clock hands rotate smoothly to 12 o'clock.
class TimelapseIconPainter extends CustomPainter {
  const TimelapseIconPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;
    final strokeWidth = size.width * 0.08;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Dial plate
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF1C1F24),
    );

    // Outer track ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF2A2F37)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Remaining sweep shrinks from 270 deg (3/4 turn) down to 0 at 12 o'clock.
    final remainingSweep = (1.5 * math.pi) * (1.0 - progress).clamp(0.0, 1.0);
    const topAngle = -math.pi / 2;

    if (remainingSweep > 0.001) {
      // Countdown wedge
      final wedgeRect = Rect.fromCircle(
        center: center,
        radius: radius - strokeWidth * 0.5,
      );
      canvas.drawArc(
        wedgeRect,
        topAngle - remainingSweep,
        remainingSweep,
        true,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x38FF8A00), Color(0x24FF5252)],
          ).createShader(wedgeRect),
      );

      // Gradient progress arc
      canvas.drawArc(
        rect,
        topAngle - remainingSweep,
        remainingSweep,
        false,
        Paint()
          ..shader = const SweepGradient(
            startAngle: 0,
            endAngle: math.pi * 2,
            colors: [Color(0xFFFF8A00), Color(0xFFFF5252), Color(0xFFFF8A00)],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // 12 o'clock marker dot
    canvas.drawCircle(
      Offset(center.dx, center.dy - (radius - strokeWidth * 0.95)),
      size.width * 0.015,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );

    // Minute hand: rotates 1 full turn clockwise to 12 o'clock (topAngle)
    final minuteAngle = topAngle - (2 * math.pi * (1.0 - progress));
    final minuteEnd = Offset(
      center.dx + math.cos(minuteAngle) * (radius * 0.62),
      center.dy + math.sin(minuteAngle) * (radius * 0.62),
    );
    canvas.drawLine(
      center,
      minuteEnd,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..strokeWidth = size.width * 0.038
        ..strokeCap = StrokeCap.round,
    );

    // Hour hand: rotates from 9 o'clock (-pi) clockwise to 12 o'clock (topAngle)
    final hourAngle = topAngle - (0.5 * math.pi * (1.0 - progress));
    final hourEnd = Offset(
      center.dx + math.cos(hourAngle) * (radius * 0.44),
      center.dy + math.sin(hourAngle) * (radius * 0.44),
    );
    canvas.drawLine(
      center,
      hourEnd,
      Paint()
        ..color = const Color(0xFFFF8A00)
        ..strokeWidth = size.width * 0.046
        ..strokeCap = StrokeCap.round,
    );

    // Center pivot
    canvas.drawCircle(
      center,
      size.width * 0.04,
      Paint()..color = const Color(0xFFFF8A00),
    );
    canvas.drawCircle(
      center,
      size.width * 0.017,
      Paint()..color = const Color(0xFF121417),
    );
  }

  @override
  bool shouldRepaint(covariant TimelapseIconPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
