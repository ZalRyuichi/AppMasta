import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/music_player_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/sync_widgets.dart';

Future<void> showMusicPlayerSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MusicPlayerSheet(),
  );
}

class _MusicPlayerSheet extends StatelessWidget {
  const _MusicPlayerSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicPlayerService>(
      builder: (context, music, _) {
        final track = music.current;
        if (track == null) {
          return const SizedBox.shrink();
        }

        final progress = music.duration.inMilliseconds == 0
            ? 0.0
            : (music.position.inMilliseconds / music.duration.inMilliseconds)
                .clamp(0.0, 1.0);

        return DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          builder: (context, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: ElegantCard.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AppColors.neoBlack, width: 3),
              ),
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.neoBlack.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.neoBlack, width: 3),
                        boxShadow: NeoShadow.hard(dx: 6, dy: 6),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: track.imageUrl.isEmpty
                          ? Container(
                              color: AppColors.dashAccent,
                              child: const Icon(Icons.album, size: 80, color: Colors.white),
                            )
                          : CachedNetworkImage(
                              imageUrl: track.imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: AppColors.dashAccent,
                                child: const Icon(Icons.album, size: 80, color: Colors.white),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    track.name,
                    textAlign: TextAlign.center,
                    style: AppTypography.brand(size: 22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artistName,
                    textAlign: TextAlign.center,
                    style: AppTypography.menuSubtitle(),
                  ),
                  if (track.albumName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      track.albumName,
                      textAlign: TextAlign.center,
                      style: AppTypography.welcomeMeta(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.dashAccent,
                      inactiveTrackColor: AppColors.neoBlack.withValues(alpha: 0.15),
                      thumbColor: AppColors.dashAccent,
                      overlayColor: AppColors.dashAccent.withValues(alpha: 0.15),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: progress,
                      onChanged: (v) {
                        final ms = (v * music.duration.inMilliseconds).round();
                        music.seek(Duration(milliseconds: ms));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          music.formatDuration(music.position),
                          style: AppTypography.techId(),
                        ),
                        Text(
                          music.formatDuration(music.duration),
                          style: AppTypography.techId(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 36,
                        onPressed: () => music.playPrevious(),
                        icon: const Icon(Icons.skip_previous_rounded),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.dashAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.neoBlack, width: 3),
                          boxShadow: NeoShadow.hard(dx: 3, dy: 3),
                        ),
                        child: IconButton(
                          onPressed: () => music.togglePlay(),
                          icon: Icon(
                            music.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        iconSize: 36,
                        onPressed: () => music.playNext(),
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
