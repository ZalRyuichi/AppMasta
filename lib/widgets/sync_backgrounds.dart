import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DarkMeshBackground extends StatelessWidget {
  const DarkMeshBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF060B16), AppColors.bg],
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.accent.withValues(alpha: 0.18), Colors.transparent]),
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -40,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.accent2.withValues(alpha: 0.08), Colors.transparent]),
            ),
          ),
        ),
        CustomPaint(painter: _GridPainter(color: AppColors.accent.withValues(alpha: 0.035))),
        child,
      ],
    );
  }
}

class SakuraMeshBackground extends StatefulWidget {
  const SakuraMeshBackground({
    super.key,
    required this.child,
    this.scanLine = false,
  });

  final Widget child;
  final bool scanLine;

  @override
  State<SakuraMeshBackground> createState() => _SakuraMeshBackgroundState();
}

class _SakuraMeshBackgroundState extends State<SakuraMeshBackground> with SingleTickerProviderStateMixin {
  AnimationController? _scanCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.scanLine) {
      _scanCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SakuraMeshBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scanLine && _scanCtrl == null) {
      _scanCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
    } else if (!widget.scanLine && _scanCtrl != null) {
      _scanCtrl!.dispose();
      _scanCtrl = null;
    }
  }

  @override
  void dispose() {
    _scanCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.dashBg,
          ),
        ),
        Positioned(
          top: -80,
          left: -30,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.dashAccent.withValues(alpha: 0.14), Colors.transparent]),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          right: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.dashAccent2.withValues(alpha: 0.12), Colors.transparent]),
            ),
          ),
        ),
        CustomPaint(painter: _DotGridPainter(color: AppColors.dashAccent.withValues(alpha: 0.045))),
        if (widget.scanLine && _scanCtrl != null)
          AnimatedBuilder(
            animation: _scanCtrl!,
            builder: (context, _) => Positioned(
              top: -40 + _scanCtrl!.value * (MediaQuery.sizeOf(context).height + 80),
              left: 0,
              right: 0,
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.dashAccent.withValues(alpha: 0.08),
                      AppColors.dashAccent.withValues(alpha: 0.35),
                      AppColors.dashAccent.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppRadius.lg,
    this.tint = AppColors.card,
    this.borderColor,
    this.blur = 0,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color tint;
  final Color? borderColor;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint.withValues(alpha: 0.96), tint.withValues(alpha: 0.88)],
        ),
        border: Border.all(color: borderColor ?? AppColors.accent.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 32, offset: const Offset(0, 16)),
          BoxShadow(color: AppColors.accent.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );

    if (blur <= 0) return panel;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: panel,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final dot = Paint()..color = color.withValues(alpha: 0.8);
    for (double x = 0; x < size.width; x += step * 3) {
      for (double y = 0; y < size.height; y += step * 3) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}