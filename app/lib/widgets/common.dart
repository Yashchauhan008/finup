import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/db.dart';
import '../theme.dart';

/// Progress of [t] inside the window [start]..[end], clamped to 0..1.
double iv(double t, double start, double end) =>
    ((t - start) / (end - start)).clamp(0.0, 1.0).toDouble();

Route<T> fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 550),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class OrbitPainter extends CustomPainter {
  final double t;
  final Color line;
  final bool showDots;
  final Alignment center;
  final double scale;

  OrbitPainter(
    this.t, {
    this.line = const Color(0x4DFFFFFF),
    this.showDots = true,
    this.center = const Alignment(-0.1, -0.35),
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = center.alongSize(size);
    final base = size.shortestSide * 0.85 * scale;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = line;
    const rings = 7;
    for (var i = 0; i < rings; i++) {
      final dir = i.isEven ? 1.0 : -1.0;
      final angle = i * math.pi / rings + dir * t * 2 * math.pi * 0.15;
      final w = base * (1.5 + 0.06 * i);
      final h = base * (0.5 + 0.09 * i);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: w, height: h), stroke);
      if (showDots && i % 2 == 0) {
        final a = dir * t * 2 * math.pi + i * 1.3;
        final pos = Offset(math.cos(a) * w / 2, math.sin(a) * h / 2);
        final dot = Paint()
          ..color = (i % 4 == 0) ? AppColors.lavender : AppColors.pink;
        canvas.drawCircle(pos, 5.0 + i * 1.6, dot);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant OrbitPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.line != line;
}

class OrbitBackground extends StatefulWidget {
  final Alignment center;
  final double scale;

  const OrbitBackground({
    super.key,
    this.center = const Alignment(-0.1, -0.35),
    this.scale = 1.0,
  });

  @override
  State<OrbitBackground> createState() => _OrbitBackgroundState();
}

class _OrbitBackgroundState extends State<OrbitBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 24))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: OrbitPainter(
            _c.value,
            center: widget.center,
            scale: widget.scale,
          ),
        ),
      ),
    );
  }
}

/// Repeats an animation forever and rebuilds with progress 0..1.
class Looping extends StatefulWidget {
  final Duration duration;
  final Widget Function(BuildContext context, double t) builder;

  const Looping({super.key, required this.duration, required this.builder});

  @override
  State<Looping> createState() => _LoopingState();
}

class _LoopingState extends State<Looping> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => widget.builder(context, _c.value),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.lavender, AppColors.pink]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, color: AppColors.ink, size: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccountCard extends StatelessWidget {
  final Account account;
  final bool hide;
  final VoidCallback? onTap;

  const AccountCard({
    super.key,
    required this.account,
    this.hide = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final digits = account.last4;
    final bottom = (digits != null && digits.isNotEmpty)
        ? '****   ****   ****   $digits'
        : account.type.label.toUpperCase();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.gradientAt(account.colorIndex),
          borderRadius: BorderRadius.circular(26),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: OrbitPainter(
                    0.15,
                    line: Colors.white.withValues(alpha: 0.18),
                    showDots: false,
                    center: const Alignment(0.7, -0.1),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(account.type.icon, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            account.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          account.type.label,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        inr(account.balance, hide: hide),
                        style: AppText.display(size: 26, color: Colors.white),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      bottom,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddAccountCard extends StatelessWidget {
  final VoidCallback onTap;

  const AddAccountCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.25), width: 1.5),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline_rounded,
                  color: Colors.white, size: 36),
              SizedBox(height: 10),
              Text(
                'Add account',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
