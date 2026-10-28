import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class DashboardHeroVideo extends StatefulWidget {
  const DashboardHeroVideo({super.key});

  @override
  State<DashboardHeroVideo> createState() => _DashboardHeroVideoState();
}

class _DashboardHeroVideoState extends State<DashboardHeroVideo> {
  late VideoPlayerController _controller;
  bool _hasError = false;

  static final _radius = BorderRadius.circular(AppRadius.lg);

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset(
      'assets/videos/dashboard_intro.mp4',
    )
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.play();
        }
      }).catchError((_) {
        if (mounted) setState(() => _hasError = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.dashAccent.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.dashAccent.withValues(alpha: 0.2),
            ),
          ),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_controller.value.isInitialized)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(),
                  ),

                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.35),
                      ],
                      stops: const [0.0, 0.35, 1.0],
                    ),
                  ),
                ),

                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Text(
                    'VOID SPY',
                    style: AppTypography.brandLogo(
                      size: 22,
                      color: const Color(0xFF39E75F),
                      shadow: const Color(0xFF00C853),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}