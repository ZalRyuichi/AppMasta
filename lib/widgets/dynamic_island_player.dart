import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/music/music_player_sheet.dart';
import '../services/music_player_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Mini player ala Dynamic Island — compact by default, expand on tap, draggable.
class DynamicIslandPlayer extends StatefulWidget {
  const DynamicIslandPlayer({super.key});

  @override
  State<DynamicIslandPlayer> createState() => _DynamicIslandPlayerState();
}

class _DynamicIslandPlayerState extends State<DynamicIslandPlayer> {
  bool _expanded = false;

  /// Posisi relatif dari pojok kiri-atas (setelah SafeArea top).
  Offset _offset = const Offset(0, 8);
  bool _initialized = false;

  static const double _compactHeight = 40;
  static const double _compactMaxWidth = 220;
  static const double _artCompact = 28;
  static const double _artExpanded = 48;

  void _ensureInitialPos(Size screen, EdgeInsets padding) {
    if (_initialized) return;
    _initialized = true;
    // Center horizontally, near top
    final w = _compactMaxWidth;
    _offset = Offset((screen.width - w) / 2, padding.top + 6);
  }

  void _onDragUpdate(DragUpdateDetails d, Size screen, EdgeInsets padding) {
    setState(() {
      final maxW = _expanded ? screen.width - 32 : _compactMaxWidth;
      final maxH = _expanded ? 150.0 : _compactHeight;
      var nx = _offset.dx + d.delta.dx;
      var ny = _offset.dy + d.delta.dy;
      // Clamp dalam layar
      nx = nx.clamp(8.0, screen.width - maxW - 8);
      ny = ny.clamp(padding.top + 4, screen.height - maxH - padding.bottom - 80);
      _offset = Offset(nx, ny);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicPlayerService>(
      builder: (context, music, _) {
        final track = music.current;
        if (track == null) return const SizedBox.shrink();

        final media = MediaQuery.of(context);
        final screen = media.size;
        final padding = media.padding;
        _ensureInitialPos(screen, padding);

        final progress = music.duration.inMilliseconds <= 0
            ? 0.0
            : (music.position.inMilliseconds / music.duration.inMilliseconds)
                .clamp(0.0, 1.0);

        return Positioned(
          left: _offset.dx,
          top: _offset.dy,
          child: GestureDetector(
            onPanUpdate: (d) => _onDragUpdate(d, screen, padding),
            child: Material(
              color: Colors.transparent,
              elevation: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: _expanded ? (screen.width - 32).clamp(280.0, 360.0) : null,
                constraints: _expanded
                    ? null
                    : const BoxConstraints(maxWidth: _compactMaxWidth),
                child: _expanded
                    ? _ExpandedCard(
                        music: music,
                        trackName: track.name,
                        artistName: track.artistName,
                        imageUrl: track.imageUrl,
                        progress: progress,
                        onCollapse: () => setState(() => _expanded = false),
                        onOpenFull: () => showMusicPlayerSheet(context),
                      )
                    : _CompactPill(
                        music: music,
                        trackName: track.name,
                        imageUrl: track.imageUrl,
                        progress: progress,
                        onTap: () => setState(() => _expanded = true),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// COMPACT (kecil, seperti gambar 2)
// ─────────────────────────────────────────────
class _CompactPill extends StatelessWidget {
  const _CompactPill({
    required this.music,
    required this.trackName,
    required this.imageUrl,
    required this.progress,
    required this.onTap,
  });

  final MusicPlayerService music;
  final String trackName;
  final String imageUrl;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _DynamicIslandPlayerState._compactHeight,
        padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white12, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Art(imageUrl: imageUrl, size: _DynamicIslandPlayerState._artCompact, radius: 14),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                trackName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Mini equalizer / playing indicator
            Icon(
              music.isPlaying ? Icons.graphic_eq_rounded : Icons.pause_rounded,
              color: AppColors.dashAccent,
              size: 16,
            ),
            const SizedBox(width: 2),
            Icon(
              music.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EXPANDED (seperti gambar 1 — floating card)
// ─────────────────────────────────────────────
class _ExpandedCard extends StatelessWidget {
  const _ExpandedCard({
    required this.music,
    required this.trackName,
    required this.artistName,
    required this.imageUrl,
    required this.progress,
    required this.onCollapse,
    required this.onOpenFull,
  });

  final MusicPlayerService music;
  final String trackName;
  final String artistName;
  final String imageUrl;
  final double progress;
  final VoidCallback onCollapse;
  final VoidCallback onOpenFull;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'SKYLINE MUSIC',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onOpenFull,
                  child: const Icon(Icons.open_in_full_rounded, color: Colors.white54, size: 16),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onCollapse,
                  child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white54, size: 20),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => music.stop(),
                  child: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                _Art(imageUrl: imageUrl, size: _DynamicIslandPlayerState._artExpanded, radius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trackName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Progress
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: Colors.white12,
                          color: AppColors.dashAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _fmt(music.position),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 9),
                          ),
                          Text(
                            _fmt(music.duration),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Controls
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => music.togglePlay(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.dashAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          music.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => music.playNext(),
                      child: const Icon(Icons.skip_next_rounded, color: Colors.white60, size: 22),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared artwork
// ─────────────────────────────────────────────
class _Art extends StatelessWidget {
  const _Art({required this.imageUrl, required this.size, required this.radius});

  final String imageUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      color: AppColors.dashAccent.withValues(alpha: 0.3),
      child: Icon(Icons.music_note, color: Colors.white70, size: size * 0.45),
    );
  }
}
