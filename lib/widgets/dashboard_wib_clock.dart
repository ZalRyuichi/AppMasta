import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class DashboardWibClock extends StatefulWidget {
  const DashboardWibClock({super.key});

  @override
  State<DashboardWibClock> createState() => _DashboardWibClockState();
}

class _DashboardWibClockState extends State<DashboardWibClock> with SingleTickerProviderStateMixin {
  static const _surface = Color(0xFFFFFCFE);

  AnimationController? _pulseCtrl;
  Timer? _timer;
  DateTime _now = DateTime.now().toUtc().add(const Duration(hours: 7));

  static const _monthsId = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  static const _daysId = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _startClock();
  }

  @override
  void reassemble() {
    super.reassemble();
    _now = _wibNow;
    _startClock();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl?.dispose();
    super.dispose();
  }

  void _startClock() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = _wibNow);
    });
  }

  DateTime get _wibNow => DateTime.now().toUtc().add(const Duration(hours: 7));

  String _pad(int v) => v.toString().padLeft(2, '0');

  String _dateLabel(DateTime dt) {
    final dayName = _daysId[dt.weekday - 1];
    final monthName = _monthsId[dt.month - 1];
    return '$dayName, ${dt.day} $monthName ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hh = _pad(_now.hour);
    final mm = _pad(_now.minute);
    final ss = _pad(_now.second);
    final colonVisible = _now.second.isEven;
    final pulse = _pulseCtrl?.value ?? 0;

    return AnimatedBuilder(
      animation: _pulseCtrl ?? const AlwaysStoppedAnimation(0),
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: _surface,
            border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: AppColors.dashAccent.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 16,
                  bottom: 16,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppColors.dashAccent.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    color: AppColors.dashAccent.withValues(alpha: 0.55),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 12,
                  child: Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppColors.dashAccent.withValues(alpha: 0.22),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 14,
                  child: _CornerDot(),
                ),
                Positioned(
                  bottom: 10,
                  right: 14,
                  child: _CornerDot(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 18, 14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _WibBadge(pulse: pulse),
                          const SizedBox(width: 10),
                          Text('Waktu Indonesia Barat', style: AppTypography.statLabel()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _DecorLine()),
                          const SizedBox(width: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              _TimeBlock(value: hh),
                              _BlinkColon(visible: colonVisible),
                              _TimeBlock(value: mm),
                              _BlinkColon(visible: colonVisible),
                              _SecondsBlock(key: ValueKey(ss), value: ss),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _DecorLine()),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.dashBg,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          _dateLabel(_now),
                          style: AppTypography.welcomeMeta().copyWith(fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CornerDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.dashAccent.withValues(alpha: 0.2),
      ),
    );
  }
}

class _DecorLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.dashAccent.withValues(alpha: 0.2),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _WibBadge extends StatelessWidget {
  const _WibBadge({required this.pulse});

  final double pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: AppColors.dashAccent.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.dashAccent,
              boxShadow: [
                BoxShadow(
                  color: AppColors.dashAccent.withValues(alpha: 0.45 + pulse * 0.25),
                  blurRadius: 5 + pulse * 3,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text('WIB', style: AppTypography.tagline(color: AppColors.dashAccent)),
        ],
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: AppTypography.statValue(active: true).copyWith(
        fontSize: 32,
        letterSpacing: 1.4,
        color: const Color(0xFF5C2440),
      ),
    );
  }
}

class _SecondsBlock extends StatelessWidget {
  const _SecondsBlock({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        value,
        key: ValueKey<String>(value),
        style: AppTypography.statValue(active: true).copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _BlinkColon extends StatelessWidget {
  const _BlinkColon({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0.25,
      duration: const Duration(milliseconds: 220),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Text(
          ':',
          style: AppTypography.statValue(active: true).copyWith(
            fontSize: 28,
            color: AppColors.dashAccent.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}