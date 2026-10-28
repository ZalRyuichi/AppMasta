import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/role_config.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'profile_avatar.dart';
import 'sakura_profile_decor.dart';

class DashboardWelcomeOrb extends StatefulWidget {
  const DashboardWelcomeOrb({
    super.key,
    required this.name,
    required this.role,
    required this.online,
    required this.onTap,
    this.avatarPath,
  });

  final String name;
  final String role;
  final int online;
  final VoidCallback onTap;
  final String? avatarPath;

  @override
  State<DashboardWelcomeOrb> createState() => _DashboardWelcomeOrbState();
}

class _DashboardWelcomeOrbState extends State<DashboardWelcomeOrb> with TickerProviderStateMixin {
  static const _orbSize = 128.0;

  AnimationController? _spinOuter;
  AnimationController? _spinInner;
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    _startOrbMotion();
  }

  @override
  void dispose() {
    _spinOuter?.dispose();
    _spinInner?.dispose();
    _pulse?.dispose();
    super.dispose();
  }

  void _startOrbMotion() {
    _spinOuter ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat();
    _spinInner ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
    _pulse ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = RoleConfig.roleLabels[widget.role] ?? widget.role;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(999),
        splashColor: AppColors.dashAccent.withValues(alpha: 0.1),
        highlightColor: AppColors.dashAccent.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_spinOuter, _spinInner, _pulse].whereType<Listenable>()),
                builder: (context, _) {
                  final drift = _pulse?.value ?? 0;
                  return SizedBox(
                    width: double.infinity,
                    height: _orbSize + 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SakuraProfileDecor(
                            side: SakuraDecorSide.left,
                            drift: drift,
                          ),
                        ),
                        SizedBox(
                          width: _orbSize,
                          height: _orbSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size.square(_orbSize),
                                painter: _OrbRingPainter(
                                  rotation: (_spinOuter?.value ?? 0) * math.pi * 2,
                                  segments: 10,
                                  strokeWidth: 4,
                                  gapRadians: 0.28,
                                  color: AppColors.dashAccent.withValues(alpha: 0.82),
                                  glowColor: AppColors.dashAccent.withValues(alpha: 0.28),
                                ),
                              ),
                              CustomPaint(
                                size: const Size.square(_orbSize * 0.84),
                                painter: _OrbRingPainter(
                                  rotation: -(_spinInner?.value ?? 0) * math.pi * 2,
                                  segments: 6,
                                  strokeWidth: 2.8,
                                  gapRadians: 0.42,
                                  color: AppColors.dashAccent2.withValues(alpha: 0.7),
                                  glowColor: AppColors.dashAccentSoft.withValues(alpha: 0.22),
                                ),
                              ),
                              CustomPaint(
                                size: const Size.square(_orbSize * 0.94),
                                painter: _OrbTicksPainter(rotation: (_spinOuter?.value ?? 0) * math.pi * 2),
                              ),
                              ProfileAvatar(
                                name: widget.name,
                                imagePath: widget.avatarPath,
                                size: _orbSize * 0.58,
                                fontSize: 28,
                                borderColor: Colors.white.withValues(alpha: 0.95),
                                borderWidth: 2.5,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SakuraProfileDecor(
                            side: SakuraDecorSide.right,
                            drift: drift,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text('Halo, ${widget.name}', style: AppTypography.welcomeName()),
              const SizedBox(height: 4),
              Text(
                '$roleLabel · ${widget.online} device online',
                style: AppTypography.welcomeMeta(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: AppColors.dashAccent.withValues(alpha: 0.08),
                  border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.14)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline_rounded, size: 14, color: AppColors.dashAccent.withValues(alpha: 0.85)),
                    const SizedBox(width: 6),
                    Text(
                      'Lihat Profil',
                      style: AppTypography.menuSubtitle().copyWith(
                        fontSize: 11,
                        color: AppColors.dashAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.dashAccent.withValues(alpha: 0.7)),
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

class _OrbRingPainter extends CustomPainter {
  _OrbRingPainter({
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
    final rect = Rect.fromCircle(center: center, radius: radius);

    final glow = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < segments; i++) {
      final start = rotation + i * (math.pi * 2 / segments);
      canvas.drawArc(rect, start, sweep, false, glow);
      canvas.drawArc(rect, start, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbRingPainter old) {
    return old.rotation != rotation || old.color != color;
  }
}

class _OrbTicksPainter extends CustomPainter {
  _OrbTicksPainter({required this.rotation});

  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = AppColors.dashAccent.withValues(alpha: 0.28)
      ..strokeWidth = 1;

    for (var i = 0; i < 24; i++) {
      final angle = rotation + i * (math.pi * 2 / 24);
      final inner = radius - (i % 4 == 0 ? 8 : 5);
      final outer = radius - 1.5;
      final p1 = Offset(center.dx + math.cos(angle) * inner, center.dy + math.sin(angle) * inner);
      final p2 = Offset(center.dx + math.cos(angle) * outer, center.dy + math.sin(angle) * outer);
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbTicksPainter old) => old.rotation != rotation;
}