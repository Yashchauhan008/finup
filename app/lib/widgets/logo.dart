import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class FinUpLogo extends StatelessWidget {
  final double size;
  final bool withBackground;

  const FinUpLogo({super.key, this.size = 64, this.withBackground = true});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        size: Size.square(size), painter: _LogoPainter(withBackground));
  }
}

class _LogoPainter extends CustomPainter {
  final bool bg;
  _LogoPainter(this.bg);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200);
    if (bg) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 200, 200), const Radius.circular(46)),
        Paint()..color = AppColors.indigo,
      );
    }
    canvas.save();
    canvas.translate(100, 104);
    canvas.rotate(-28 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 156, height: 60),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.lavender.withValues(alpha: 0.45),
    );
    canvas.restore();
    canvas.drawCircle(const Offset(169, 67), 8, Paint()..color = AppColors.pink);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.lavender;
    final f = Path()
      ..moveTo(78, 148)
      ..lineTo(78, 80)
      ..quadraticBezierTo(78, 62, 96, 59)
      ..lineTo(128, 51);
    canvas.drawPath(f, stroke);
    canvas.drawLine(const Offset(78, 104), const Offset(112, 104), stroke);
    final arrow = Path()
      ..moveTo(112, 40)
      ..lineTo(134, 50)
      ..lineTo(118, 68);
    stroke.color = AppColors.pink;
    canvas.drawPath(arrow, stroke);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => oldDelegate.bg != bg;
}
