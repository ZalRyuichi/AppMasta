import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/track_model.dart';
import '../../services/music_player_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/sync_backgrounds.dart';
import '../../widgets/sync_widgets.dart';
import 'music_player_sheet.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSearch(MusicPlayerService music) async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      await music.loadPopular();
    } else {
      await music.search(q);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('VOID SPY MUSIC', style: AppTypography.brand(size: 20)),
        ),
        body: SakuraMeshBackground(
          child: Consumer<MusicPlayerService>(
            builder: (context, music, _) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: ElegantCard.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.neoBlack, width: 2.5),
                        boxShadow: NeoShadow.hard(dx: 3, dy: 3),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        style: AppTypography.menuSubtitle(),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _onSearch(music),
                        decoration: InputDecoration(
                          hintText: 'Cari lagu / artist...',
                          hintStyle: AppTypography.welcomeMeta(),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.dashAccent),
                          suffixIcon: IconButton(
                            onPressed: () => _onSearch(music),
                            icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.neoBlack),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          music.lastQuery.isEmpty ? 'POPULER' : 'HASIL PENCARIAN',
                          style: AppTypography.statLabel(),
                        ),
                        const Spacer(),
                        if (music.searching)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dashAccent),
                          ),
                      ],
                    ),
                  ),
                  if (music.error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(music.error!, style: AppTypography.menuSubtitle().copyWith(color: Colors.red)),
                    ),
                  Expanded(
                    child: music.searching && music.tracks.isEmpty
                        ? const Center(child: CircularProgressIndicator(color: AppColors.dashAccent))
                        : music.tracks.isEmpty
                            ? Center(
                                child: Text(
                                  'Tidak ada lagu ditemukan',
                                  style: AppTypography.menuSubtitle(),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                                itemCount: music.tracks.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final track = music.tracks[i];
                                  final playing = music.current?.id == track.id;
                                  return _TrackTile(
                                    track: track,
                                    playing: playing,
                                    isPlaying: playing && music.isPlaying,
                                    onTap: () async {
                                      await music.playTrack(track, fromList: music.tracks);
                                      if (context.mounted) showMusicPlayerSheet(context);
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.playing,
    required this.isPlaying,
    required this.onTap,
  });

  final TrackModel track;
  final bool playing;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: playing ? AppColors.dashAccent.withValues(alpha: 0.08) : ElegantCard.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: playing ? AppColors.dashAccent : AppColors.neoBlack,
              width: playing ? 2.5 : 2,
            ),
            boxShadow: NeoShadow.hard(dx: 2, dy: 2),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: track.imageUrl.isEmpty
                    ? Container(
                        width: 52,
                        height: 52,
                        color: AppColors.dashAccent,
                        child: const Icon(Icons.music_note, color: Colors.white),
                      )
                    : CachedNetworkImage(
                        imageUrl: track.imageUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 52,
                          height: 52,
                          color: AppColors.dashAccent,
                          child: const Icon(Icons.music_note, color: Colors.white),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.menuTitle().copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${track.artistName} · ${track.durationLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.menuSubtitle().copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                isPlaying ? Icons.equalizer_rounded : Icons.play_circle_filled_rounded,
                color: playing ? AppColors.dashAccent : AppColors.neoBlack,
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
