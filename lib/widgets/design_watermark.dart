import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

abstract final class DesignCredit {
  static const label = 'Design By : @KairoOfficialkuu';
  static const handle = '@KairoOfficialkuu';
}

class DesignWatermarkInline extends StatelessWidget {
  const DesignWatermarkInline({
    super.key,
    this.align = TextAlign.center,
    this.opacity = 0.42,
    this.fontSize = 9.5,
  });

  final TextAlign align;
  final double opacity;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      DesignCredit.label,
      textAlign: align,
      style: AppTypography.menuSubtitle().copyWith(
        fontSize: fontSize,
        letterSpacing: 0.35,
        fontWeight: FontWeight.w600,
        color: AppColors.dashTextMuted.withValues(alpha: opacity),
      ),
    );
  }
}

class DesignWatermarkCorner extends StatelessWidget {
  const DesignWatermarkCorner({
    super.key,
    this.alignment = Alignment.bottomRight,
    this.padding = const EdgeInsets.fromLTRB(12, 0, 14, 92),
    this.opacity = 0.28,
    this.rotate = 0,
  });

  final Alignment alignment;
  final EdgeInsets padding;
  final double opacity;
  final double rotate;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: padding,
          child: Transform.rotate(
            angle: rotate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: Colors.white.withValues(alpha: 0.45),
                border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.1)),
              ),
              child: Text(
                DesignCredit.label,
                style: AppTypography.menuSubtitle().copyWith(
                  fontSize: 8.5,
                  letterSpacing: 0.25,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dashAccent.withValues(alpha: opacity + 0.15),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DesignWatermarkScatter extends StatelessWidget {
  const DesignWatermarkScatter({super.key, this.opacity = 0.045});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          if (!w.isFinite || !h.isFinite || w <= 0 || h <= 0) {
            return const SizedBox.shrink();
          }

          final spots = <Offset>[
            Offset(w * 0.12, h * 0.22),
            Offset(w * 0.78, h * 0.38),
            Offset(w * 0.34, h * 0.72),
          ];

          return Stack(
            fit: StackFit.expand,
            children: [
              for (var i = 0; i < spots.length; i++)
                Positioned(
                  left: spots[i].dx,
                  top: spots[i].dy,
                  child: Transform.rotate(
                    angle: (-14 + i * 9) * math.pi / 180,
                    child: Text(
                      DesignCredit.handle,
                      style: TextStyle(
                        fontSize: 11 + i.toDouble(),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.dashAccent.withValues(alpha: opacity),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class DesignWatermarkLayer extends StatelessWidget {
  const DesignWatermarkLayer({
    super.key,
    required this.child,
    this.showScatter = true,
    this.showCorner = true,
  });

  final Widget child;
  final bool showScatter;
  final bool showCorner;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (showScatter) const DesignWatermarkScatter(),
        if (showCorner) ...const [
          DesignWatermarkCorner(
            alignment: Alignment.bottomRight,
            padding: EdgeInsets.fromLTRB(0, 0, 12, 88),
          ),
          DesignWatermarkCorner(
            alignment: Alignment.topLeft,
            padding: EdgeInsets.fromLTRB(10, 8, 0, 0),
            opacity: 0.2,
            rotate: -0.08,
          ),
        ],
      ],
    );
  }
}