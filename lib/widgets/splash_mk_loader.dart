import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SplashMkLoader extends StatefulWidget {
  const SplashMkLoader({super.key, this.size = 220});

  final double size;

  @override
  State<SplashMkLoader> createState() => _SplashMkLoaderState();
}

class _SplashMkLoaderState extends State<SplashMkLoader> with TickerProviderStateMixin {
  late final AnimationController _spinOuter;
  late final AnimationController _spinInner;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _spinOuter = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();
    _spinInner = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))..repeat();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spinOuter.dispose();
    _spinInner.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_spinOuter, _spinInner, _pulse]),
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(widget.size),
                painter: _MkRingPainter(
                  rotation: _spinOuter.value * math.pi * 2,
                  segments: 12,
                  strokeWidth: 5,
                  gapRadians: 0.22,
                  color: AppColors.dashAccent.withValues(alpha: 0.85),
                  glowColor: AppColors.dashAccent.withValues(alpha: 0.35),
                ),
              ),
              CustomPaint(
                size: Size.square(widget.size * 0.82),
                painter: _MkRingPainter(
                  rotation: -_spinInner.value * math.pi * 2,
                  segments: 8,
                  strokeWidth: 3.5,
                  gapRadians: 0.38,
                  color: _MkTone.deep.withValues(alpha: 0.75),
                  glowColor: AppColors.dashAccent2.withValues(alpha: 0.2),
                ),
              ),
              CustomPaint(
                size: Size.square(widget.size * 0.94),
                painter: _MkTicksPainter(rotation: _spinOuter.value * math.pi * 2),
              ),
              Container(
                width: widget.size * 0.52,
                height: widget.size * 0.52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.dashAccent.withValues(alpha: 0.25 + _pulse.value * 0.15),
                      blurRadius: 24 + _pulse.value * 10,
                      spreadRadius: _pulse.value * 2,
                    ),
                  ],
                  image: const DecorationImage(
                    image: AssetImage('assets/images/splash.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MkRingPainter extends CustomPainter {
  _MkRingPainter({
    required this.rotation,
    required this.segments,
    required this.strokeWidth,
    required this.gapRadians,
    required this.color,
    required this.glowColor,
  });

  final double rotation;
  final int segments;
  final double strokeWidth;
  final double gapRadians;
  final Color color;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final sweep = (math.pi * 2 / segments) - gapRadians;

    final glow = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    for (var i = 0; i < segments; i++) {
      final start = rotation + i * (math.pi * 2 / segments);
      canvas.drawArc(rect, start, sweep, false, glow);
      canvas.drawArc(rect, start, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MkRingPainter old) {
    return old.rotation != rotation || old.color != color;
  }
}

class _MkTicksPainter extends CustomPainter {
  _MkTicksPainter({required this.rotation});

  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = AppColors.dashAccent.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;

    for (var i = 0; i < 36; i++) {
      final angle = rotation + i * (math.pi * 2 / 36);
      final inner = radius - (i % 3 == 0 ? 10 : 6);
      final outer = radius - 2;
      final p1 = Offset(center.dx + math.cos(angle) * inner, center.dy + math.sin(angle) * inner);
      final p2 = Offset(center.dx + math.cos(angle) * outer, center.dy + math.sin(angle) * outer);
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MkTicksPainter old) => old.rotation != rotation;
}

abstract final class _MkTone {
  static const deep = Color(0xFF6B2848);
}