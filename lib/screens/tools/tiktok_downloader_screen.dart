import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/sync_backgrounds.dart';
import '../../widgets/sync_widgets.dart';

class TiktokDownloaderScreen extends StatefulWidget {
  const TiktokDownloaderScreen({super.key});

  @override
  State<TiktokDownloaderScreen> createState() => _TiktokDownloaderScreenState();
}

class _TiktokDownloaderScreenState extends State<TiktokDownloaderScreen> {
  final _urlController = TextEditingController();
  bool _isLoading = false;
  bool _isSharing = false;
  Map<String, dynamic>? _videoData;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  @override
  void dispose() {
    _urlController.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _downloadTiktok() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      showSyncSnack(context, 'URL TikTok tidak boleh kosong', error: true);
      return;
    }
    if (!url.contains('tiktok.com')) {
      showSyncSnack(context, 'Link TikTok tidak valid', error: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _videoData = null;
      _videoController?.dispose();
      _chewieController?.dispose();
      _videoController = null;
      _chewieController = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://ssstik.io/abc?url=dl'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'hx-current-url': 'https://ssstik.io/en',
          'hx-request': 'true',
          'hx-target': 'target',
          'user-agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36',
        },
        body: {'id': url, 'locale': 'en', 'tt': 'UVh4Z3Z4'},
      );

      if (response.statusCode != 200) {
        if (mounted) showSyncSnack(context, 'Server error: ${response.statusCode}', error: true);
        return;
      }

      final html = response.body;
      final regExp = RegExp(r'href="(https://tikcdn\.io/ssstik/[^"]+)"');
      final match = regExp.firstMatch(html);

      if (match == null || match.group(1) == null) {
        if (mounted) showSyncSnack(context, 'Gagal mendapatkan link download', error: true);
        return;
      }

      final titleRegExp = RegExp(r'<p class="maintext">([^<]+)</p>');
      final titleMatch = titleRegExp.firstMatch(html);
      final title = titleMatch?.group(1) ?? 'SKYLINE Video';

      setState(() {
        _videoData = {
          'title': title,
          'videoUrl': match.group(1)!,
          'creator': 'TikTok User',
        };
      });
      _initializeVideoPlayer();
    } catch (e) {
      if (mounted) showSyncSnack(context, 'Koneksi gagal: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initializeVideoPlayer() {
    final videoUrl = _videoData?['videoUrl']?.toString();
    if (videoUrl == null || videoUrl.isEmpty) return;

    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: true,
            looping: false,
            showControls: true,
            materialProgressColors: ChewieProgressColors(
              playedColor: AppColors.dashAccent,
              handleColor: AppColors.dashAccent2,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              bufferedColor: Colors.white.withValues(alpha: 0.25),
            ),
          );
        });
      });
  }

  Future<void> _shareVideo() async {
    if (_videoData == null) return;
    setState(() => _isSharing = true);

    try {
      final videoUrl = _videoData!['videoUrl']?.toString();
      if (videoUrl == null || videoUrl.isEmpty) {
        if (mounted) showSyncSnack(context, 'Link video rusak', error: true);
        return;
      }

      final response = await http.get(Uri.parse(videoUrl));
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/skyline_tiktok_${DateTime.now().millisecondsSinceEpoch}.mp4');
      await file.writeAsBytes(response.bodyBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Downloaded via SKYLINE — ${_videoData!['creator']}',
      );
    } catch (e) {
      if (mounted) showSyncSnack(context, 'Gagal membagikan: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text('TIKTOK SAVER', style: AppTypography.brand(size: 18)),
        ),
        body: SakuraMeshBackground(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.paddingOf(context).bottom),
            children: [
              FadeSlideIn(
                child: ElegantCard(
                  accent: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: AppColors.dashAccent.withValues(alpha: 0.12),
                            ),
                            child: const Icon(Icons.auto_awesome_motion_rounded, color: AppColors.dashAccent, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('TikTok Saver', style: AppTypography.menuTitle().copyWith(fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _urlController,
                        style: AppTypography.menuTitle().copyWith(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'https://vt.tiktok.com/...',
                          prefixIcon: Icon(Icons.link_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SyncPrimaryButton(
                        label: 'DOWNLOAD & SIMPAN',
                        icon: Icons.download_rounded,
                        loading: _isLoading,
                        variant: ButtonVariant.light,
                        onPressed: _downloadTiktok,
                      ),
                    ],
                  ),
                ),
              ),
              if (_videoData != null) ...[
                const SizedBox(height: 14),
                FadeSlideIn(
                  child: ElegantCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.dashAccent.withValues(alpha: 0.1),
                                border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.25)),
                              ),
                              child: const Icon(Icons.person_rounded, color: AppColors.dashAccent, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_videoData!['creator']?.toString() ?? 'TikTok', style: AppTypography.menuTitle()),
                                  Text(
                                    _videoData!['title']?.toString() ?? 'Media ready',
                                    style: AppTypography.menuSubtitle().copyWith(fontSize: 11),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_chewieController != null && _videoController != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: Chewie(controller: _chewieController!),
                            ),
                          )
                        else
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(36),
                              child: CircularProgressIndicator(color: AppColors.dashAccent, strokeWidth: 2.5),
                            ),
                          ),
                        const SizedBox(height: 16),
                        SyncPrimaryButton(
                          label: 'EXPORT & SHARE',
                          icon: Icons.share_rounded,
                          loading: _isSharing,
                          variant: ButtonVariant.light,
                          onPressed: _shareVideo,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}