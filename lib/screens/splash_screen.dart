import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/splash_mk_loader.dart';
import '../widgets/sync_backgrounds.dart';
import '../widgets/sync_widgets.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _introCtrl;
  late final Animation<double> _fade;
  late final Animation<double> _slide;
  late final Animation<double> _scale;

  int _statusIndex = 0;
  static const _statusLines = [
    'Memuat antarmuka',
    'Menyiapkan panel kontrol',
    'Sinkronisasi perangkat',
    'Hampir siap',
  ];

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

    _fade = CurvedAnimation(parent: _introCtrl, curve: const Interval(0, 0.6, curve: AppMotion.curve));
    _slide = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(parent: _introCtrl, curve: const Interval(0, 0.75, curve: AppMotion.spring)),
    );
    _scale = Tween<double>(begin: 0.97, end: 1).animate(
      CurvedAnimation(parent: _introCtrl, curve: const Interval(0, 0.8, curve: AppMotion.spring)),
    );

    _introCtrl.forward();
    _boot();
    _cycleStatus();
  }

  Future<void> _cycleStatus() async {
    while (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 580));
      if (!mounted) return;
      setState(() => _statusIndex = (_statusIndex + 1) % _statusLines.length);
    }
  }

  Future<void> _boot() async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(syncPageRoute(const MainShell()));
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_statusIndex + 1) / _statusLines.length;

    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        backgroundColor: _SplashTone.cream,
        body: SakuraMeshBackground(
          scanLine: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AnimatedBuilder(
                  animation: _introCtrl,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fade.value,
                      child: Transform.translate(
                        offset: Offset(0, _slide.value),
                        child: Transform.scale(scale: _scale.value, child: child),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SplashMkLoader(size: 220),
                        const SizedBox(height: 28),
                        const _SplashTitleBlock(),
                        const SizedBox(height: 26),
                        _SplashStatusBlock(
                          label: _statusLines[_statusIndex],
                          progress: progress,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: FadeTransition(
                  opacity: _fade,
                  child: Text(
                    'VOID SPY · 2026 · KAIRO',
                    textAlign: TextAlign.center,
                    style: AppTypography.welcomeMeta().copyWith(
                      letterSpacing: 2.2,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashTitleBlock extends StatelessWidget {
  const _SplashTitleBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'VOID SPY',
          style: AppTypography.brandLogo(
            size: 36,
            color: _SplashTone.deep,
            shadow: AppColors.dashAccent,
          ),
        ),
        const SizedBox(height: 12),
        const _SplashDivider(),
        const SizedBox(height: 12),
        Text(
          'THIS IS MY ERA',
          style: AppTypography.tagline(color: AppColors.dashText.withValues(alpha: 0.82)),
        ),
      ],
    );
  }
}

class _SplashDivider extends StatelessWidget {
  const _SplashDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      height: 10,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.dashAccent.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.dashAccent.withValues(alpha: 0.75),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.dashAccent.withValues(alpha: 0.28),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.dashAccent2.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashStatusBlock extends StatelessWidget {
  const _SplashStatusBlock({
    required this.label,
    required this.progress,
  });

  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: AppMotion.normal,
            switchInCurve: AppMotion.curve,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              label,
              key: ValueKey(label),
              textAlign: TextAlign.center,
              style: AppTypography.welcomeMeta().copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                color: AppColors.dashText.withValues(alpha: 0.88),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: AppColors.dashAccentSoft.withValues(alpha: 0.35)),
                  AnimatedAlign(
                    duration: AppMotion.normal,
                    curve: AppMotion.curve,
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.08, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.dashAccent,
                            AppColors.dashAccent2,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

abstract final class _SplashTone {
  static const cream = Color(0xFFFFFBFD);
  static const deep = Color(0xFF5C2440);
}