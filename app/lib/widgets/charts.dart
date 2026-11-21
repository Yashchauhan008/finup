import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

const kAmber = Color(0xFFF6A23A);

Color statusColor(double pct) {
  if (pct >= 1) return AppColors.expense;
  if (pct >= 0.8) return kAmber;
  return AppColors.income;
}

String shortInr(double v) {
  if (v >= 100000) {
    final x = v / 100000;
    return '${x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1)}L';
  }
  if (v >= 1000) {
    final x = v / 1000;
    return '${x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1)}k';
  }
  return v.toStringAsFixed(0);
}

double niceMax(double v) {
  if (v <= 0) return 3000;
  final raw = v / 3;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final n = raw / mag;
  final step = (n <= 1 ? 1 : (n <= 2 ? 2 : (n <= 5 ? 5 : 10))) * mag;
  return step * 3;
}

class MonthBars extends StatefulWidget {
  final List<DateTime> months;
  final List<double> values;
  final bool hide;

  const MonthBars(
      {super.key, required this.months, required this.values, this.hide = false});

  @override
  State<MonthBars> createState() => _MonthBarsState();
}

class _MonthBarsState extends State<MonthBars> {
  int? _sel;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    if (widget.values.isEmpty) return const SizedBox.shrink();
    final maxV = niceMax(widget.values.fold<double>(0, (a, b) => math.max(a, b)));
    const h = 150.0;
    final sel = (_sel ?? widget.values.length - 1)
        .clamp(0, widget.values.length - 1)
        .toInt();
    final accent = context.isDark ? AppColors.lavender : AppColors.indigo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.hide ? '₹ ••••' : inr(widget.values[sel], decimals: 0),
            key: ValueKey(sel),
            style: AppText.display(size: 22, color: fin.text),
          ),
        ),
        Text('Spent in ${DateFormat('MMMM yyyy').format(widget.months[sel])}',
            style: TextStyle(color: fin.subtext, fontSize: 12.5)),
        const SizedBox(height: 16),
        SizedBox(
          height: h + 28,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 34,
                height: h,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var k = 3; k >= 0; k--)
                      Text(shortInr(maxV * k / 3),
                          style: TextStyle(color: fin.subtext, fontSize: 11)),
                  ],
                ),
              ),
              for (var i = 0; i < widget.values.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _sel = i),
                    child: Column(children: [
                      SizedBox(
                        height: h,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              width: 14,
                              height: h,
                              decoration: BoxDecoration(
                                color: fin.divider.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween(
                                  begin: 0,
                                  end: (widget.values[i] / maxV)
                                      .clamp(0.0, 1.0)
                                      .toDouble()),
                              duration: Duration(milliseconds: 700 + i * 80),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, _) => Container(
                                width: 14,
                                height: h * v,
                                decoration: BoxDecoration(
                                  color: i == sel ? accent : AppColors.pink,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(DateFormat('MMM').format(widget.months[i]),
                          style: TextStyle(
                              color: i == sel ? fin.text : fin.subtext,
                              fontSize: 11.5,
                              fontWeight:
                                  i == sel ? FontWeight.w700 : FontWeight.w400)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class DonutChart extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;
  final double size;
  final Widget? center;

  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    this.size = 190,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final track = context.fin.divider;
    return TweenAnimationBuilder<double>(
      key: ValueKey(values.join(',')),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, p, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DonutPainter(values, colors, p, track),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double progress;
  final Color track;

  _DonutPainter(this.values, this.colors, this.progress, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.13;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track);
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    final gap = values.where((v) => v > 0).length > 1 ? 0.035 : 0.0;
    final full = 2 * math.pi * progress;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = full * values[i] / total;
      if (sweep <= 0) continue;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(sweep - gap, 0.001),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = colors[i % colors.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}

class ProgressRing extends StatelessWidget {
  final double value;
  final Color color;
  final double size;
  final double stroke;
  final Widget? child;

  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 64,
    this.stroke = 7,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final track = context.fin.divider;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0).toDouble()),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v, color, track, stroke),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color color;
  final Color track;
  final double stroke;

  _RingPainter(this.v, this.color, this.track, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track);
    if (v <= 0) return;
    canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * v,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.v != v || oldDelegate.color != color;
}
