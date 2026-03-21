import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../config/theme.dart';

class CircularTimerPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 (remaining)
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  CircularTimerPainter({
    required this.progress,
    this.trackColor = const Color(0xFFE5E7EB),
    required this.progressColor,
    this.strokeWidth = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularTimerPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.progressColor != progressColor;
}

Color timerProgressColor(double progress) {
  if (progress > 0.5) return AppColors.timerGreen;
  if (progress > 0.25) return AppColors.timerYellow;
  return AppColors.timerRed;
}
