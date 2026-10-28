import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class SmoothNavItem {
  final dynamic icon;
  final dynamic activeIcon;
  final String label;

  const SmoothNavItem({required this.icon, required this.activeIcon, required this.label});
}

/// Bottom navbar dengan lekukan (notch) melengkung mulus di bagian atas dan
/// bubble ikon aktif yang "naik" keluar dari bar, mengikuti gaya
/// navbar bergaya smooth/spring pada referensi.
class SmoothNavBar extends StatelessWidget {
  const SmoothNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    this.height = 68,
    this.riseHeight = 30,
    this.backgroundColor,
    this.activeColor,
    this.inactiveColor,
  });

  final List<SmoothNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final double height;
  final double riseHeight;
  final Color? backgroundColor;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.dashSurface;
    final active = activeColor ?? AppColors.dashAccent;
    final inactive = inactiveColor ?? AppColors.dashTextMuted;
    const bubbleSize = 52.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width / items.length;
        final targetCenter = itemWidth * (selectedIndex + 0.5);

        return SizedBox(
          height: height + riseHeight,
          width: width,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: targetCenter, end: targetCenter),
            duration: AppMotion.normal,
            curve: Curves.easeOutBack,
            builder: (context, centerX, _) {
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: riseHeight,
                    height: height,
                    child: CustomPaint(
                      painter: _NotchPainter(
                        notchCenter: centerX,
                        notchRadius: bubbleSize / 2 + 8,
                        dipDepth: riseHeight + bubbleSize * 0.32,
                        color: bg,
                        cornerRadius: AppRadius.lg,
                      ),
                      child: SizedBox(width: width, height: height),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: riseHeight,
                    height: height,
                    child: Row(
                      children: List.generate(items.length, (i) {
                        final isActive = i == selectedIndex;
                        final item = items[i];
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onTap(i),
                            child: SizedBox.expand(
                              child: isActive
                                  ? const SizedBox.shrink()
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _DynamicIcon(item.icon, color: inactive, size: 22),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.label,
                                          style: TextStyle(
                                            fontFamily: AppTypography.fontFamily,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: inactive,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: AppMotion.normal,
                    curve: Curves.easeOutBack,
                    left: centerX - bubbleSize / 2,
                    top: 0,
                    width: bubbleSize,
                    height: bubbleSize,
                    child: GestureDetector(
                      onTap: () => onTap(selectedIndex),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active,
                          boxShadow: NeoShadow.hard(dx: 3, dy: 3),
                          border: Border.all(color: AppColors.neoBlack, width: 3),
                        ),
                        child: _DynamicIcon(items[selectedIndex].activeIcon, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _NotchPainter extends CustomPainter {
  _NotchPainter({
    required this.notchCenter,
    required this.notchRadius,
    required this.dipDepth,
    required this.color,
    required this.cornerRadius,
  });

  final double notchCenter;
  final double notchRadius;
  final double dipDepth;
  final Color color;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final left = notchCenter - notchRadius;
    final right = notchCenter + notchRadius;

    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);
    path.lineTo(left - notchRadius * 0.6, 0);
    path.cubicTo(
      left - notchRadius * 0.05, 0,
      left + notchRadius * 0.15, dipDepth,
      notchCenter, dipDepth,
    );
    path.cubicTo(
      right - notchRadius * 0.15, dipDepth,
      right + notchRadius * 0.05, 0,
      right + notchRadius * 0.6, 0,
    );
    path.lineTo(size.width - cornerRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawShadow(path, AppColors.neoBlack, 0, false);
    // hard offset feel
    canvas.save();
    canvas.translate(3, 3);
    canvas.drawPath(path, Paint()..color = AppColors.neoBlack);
    canvas.restore();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NotchPainter oldDelegate) {
    return oldDelegate.notchCenter != notchCenter ||
        oldDelegate.color != color ||
        oldDelegate.notchRadius != notchRadius;
  }
}

// WEBA2APK_DYNAMIC_ICON_START
class _DynamicIcon extends StatelessWidget {
  final dynamic icon;
  final double? size;
  final Color? color;

  const _DynamicIcon(this.icon, {Key? key, this.size, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (icon == null) return const SizedBox(width: 0, height: 0);
    return Center(widthFactor: 1.0, heightFactor: 1.0, child: Icon(icon, size: size, color: color));
  }
}
// WEBA2APK_DYNAMIC_ICON_END
