import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum SakuraDecorSide { left, right }

class SakuraProfileDecor extends StatelessWidget {
  const SakuraProfileDecor({
    super.key,
    required this.side,
    required this.drift,
  });

  final SakuraDecorSide side;
  final double drift;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: CustomPaint(
        painter: _SakuraBranchPainter(side: side, drift: drift),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SakuraBranchPainter extends CustomPainter {
  _SakuraBranchPainter({required this.side, required this.drift});

  final SakuraDecorSide side;
  final double drift;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(
      side == SakuraDecorSide.left ? size.width * 0.82 : size.width * 0.18,
      size.height * 0.58,
    );

    canvas.save();
    if (side == SakuraDecorSide.right) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final branchGlow = Paint()
      ..color = AppColors.dashAccent.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final branch = Paint()
      ..color = const Color(0xFF8E4A68).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(origin.dx, origin.dy)
      ..cubicTo(
        origin.dx - 34,
        origin.dy - 18,
        origin.dx - 58,
        origin.dy - 42 + drift * 4,
        origin.dx - 72,
        origin.dy - 58 + drift * 3,
      )
      ..cubicTo(
        origin.dx - 48,
        origin.dy - 28,
        origin.dx - 18,
        origin.dy - 52 + drift * 2,
        origin.dx - 8,
        origin.dy - 78 + drift * 2,
      );

    canvas.drawPath(path, branchGlow);
    canvas.drawPath(path, branch);

    _drawFlower(canvas, Offset(origin.dx - 72, origin.dy - 58 + drift * 3), 16, 0.95);
    _drawFlower(canvas, Offset(origin.dx - 48, origin.dy - 34 + drift * 2), 12, 0.8);
    _drawFlower(canvas, Offset(origin.dx - 20, origin.dy - 72 + drift * 2), 14, 0.88);
    _drawFlower(canvas, Offset(origin.dx - 8, origin.dy - 78 + drift * 2), 10, 0.72);
    _drawFlower(canvas, Offset(origin.dx - 62, origin.dy - 12), 9, 0.65);

    _drawPetal(canvas, Offset(origin.dx - 30, origin.dy + 8 + drift * 6), 5, 0.45, 0.4);
    _drawPetal(canvas, Offset(origin.dx - 54, origin.dy - 4 + drift * 8), 4, 0.35, 1.1);
    _drawPetal(canvas, Offset(origin.dx - 14, origin.dy - 18 + drift * 5), 3.5, 0.3, 2.0);

    canvas.restore();
  }

  void _drawFlower(Canvas canvas, Offset center, double size, double alpha) {
    final petal = Paint()..color = AppColors.dashAccentSoft.withValues(alpha: alpha);
    final petalDeep = Paint()..color = AppColors.dashAccent.withValues(alpha: alpha * 0.55);

    for (var i = 0; i < 5; i++) {
      final angle = i * (math.pi * 2 / 5) - math.pi / 2;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(0, -size * 0.34), width: size * 0.42, height: size * 0.52),
        i.isEven ? petal : petalDeep,
      );
      canvas.restore();
    }

    canvas.drawCircle(
      center,
      size * 0.11,
      Paint()..color = AppColors.dashAccent.withValues(alpha: alpha * 0.7),
    );
  }

  void _drawPetal(Canvas canvas, Offset center, double size, double alpha, double rotation) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, -size * 0.2), width: size * 0.55, height: size * 0.75),
      Paint()..color = AppColors.dashAccentSoft.withValues(alpha: alpha),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SakuraBranchPainter old) => old.drift != drift || old.side != side;
}