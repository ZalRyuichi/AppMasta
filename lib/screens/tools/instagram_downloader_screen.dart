import 'dart:convert';
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

class InstagramDownloaderScreen extends StatefulWidget {
  const InstagramDownloaderScreen({super.key});

  @override
  State<InstagramDownloaderScreen> createState() => _InstagramDownloaderScreenState();
}

class _InstagramDownloaderScreenState extends State<InstagramDownloaderScreen> {
  final _urlController = TextEditingController();
  bool _isLoading = false;
  bool _isSharing = false;
  Map<String, dynamic>? _mediaData;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  static const _headers = {
    'accept': 'application/json, text/plain, */*',
    'content-type': 'application/x-www-form-urlencoded',
    'origin': 'https://kol.id',
    'referer': 'https://kol.id/download-video/instagram',
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36',
    'x-requested-with': 'XMLHttpRequest',
  };

  @override
  void dispose() {
    _urlController.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _downloadInstagram() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      showSyncSnack(context, 'URL Instagram tidak boleh kosong', error: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _mediaData = null;
      _videoController?.dispose();
      _chewieController?.dispose();
      _videoController = null;
      _chewieController = null;
    });

    try {
      final submitResponse = await http.post(
        Uri.parse('https://kol.id/api/v2/downloader/instagram'),
        headers: _headers,
        body: {'url': url},
      );

      if (submitResponse.statusCode != 200 && submitResponse.statusCode != 201) {
        if (mounted) showSyncSnack(context, 'Server error: ${submitResponse.statusCode}', error: true);
        return;
      }

      final submitData = jsonDecode(submitResponse.body) as Map<String, dynamic>;
      final requestId = submitData['data']?['request_id'] ?? submitData['request_id'];
      if (requestId == null) {
        if (mounted) showSyncSnack(context, 'Gagal menginisialisasi download', error: true);
        return;
      }

      Map<String, dynamic>? finalData;
      for (var attempt = 0; attempt < 15; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        final statusResponse = await http.get(
          Uri.parse('https://kol.id/api/v2/downloader/status/$requestId'),
          headers: _headers,
        );
        if (statusResponse.statusCode != 200) continue;

        final statusData = jsonDecode(statusResponse.body) as Map<String, dynamic>;
        final status = statusData['data']?['status']?.toString();
        if (status == 'completed') {
          finalData = Map<String, dynamic>.from(statusData['data'] as Map);
          break;
        }
        if (status == 'failed') {
          if (mounted) showSyncSnack(context, 'Download gagal di server', error: true);
          return;
        }
      }

      if (finalData == null) {
        if (mounted) showSyncSnack(context, 'Proses download terlalu lama, coba lagi', error: true);
        return;
      }

      String? dlLink = finalData['video_url']?.toString();
      if (dlLink == null && finalData['slides'] is List && (finalData['slides'] as List).isNotEmpty) {
        final slides = finalData['slides'] as List;
        final videoSlide = slides.cast<Map>().firstWhere(
              (s) => s['type'] == 'video',
              orElse: () => slides.first as Map,
            );
        dlLink = videoSlide['url']?.toString();
      }

      if (dlLink == null || dlLink.isEmpty) {
        if (mounted) showSyncSnack(context, 'Media tidak ditemukan', error: true);
        return;
      }

      final isVideo = finalData['type'] == 'slide' && dlLink.contains('.mp4') || finalData['video_url'] != null;

      setState(() {
        _mediaData = {
          'url': dlLink,
          'thumbnail': finalData!['thumbnail']?.toString() ?? '',
          'type': isVideo ? 'video' : 'image',
        };
      });

      if (isVideo) _initializeVideoPlayer(dlLink);
    } catch (e) {
      if (mounted) showSyncSnack(context, 'Koneksi gagal: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initializeVideoPlayer(String videoUrl) {
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

  Future<void> _shareContent() async {
    if (_mediaData == null) return;
    setState(() => _isSharing = true);

    try {
      final mediaUrl = _mediaData!['url']?.toString();
      if (mediaUrl == null || mediaUrl.isEmpty) {
        if (mounted) showSyncSnack(context, 'Link media rusak', error: true);
        return;
      }

      final response = await http.get(Uri.parse(mediaUrl));
      final tempDir = await getTemporaryDirectory();
      final extension = _mediaData!['type'] == 'video' ? 'mp4' : 'jpg';
      final file = File('${tempDir.path}/skyline_ig_${DateTime.now().millisecondsSinceEpoch}.$extension');
      await file.writeAsBytes(response.bodyBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'Downloaded via Void');
    } catch (e) {
      if (mounted) showSyncSnack(context, 'Gagal membagikan: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _mediaData?['thumbnail']?.toString() ?? '';
    final mediaUrl = _mediaData?['url']?.toString() ?? '';

    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text('INSTA SAVER', style: AppTypography.brand(size: 18)),
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
                            child: const Icon(Icons.camera_alt_rounded, color: AppColors.dashAccent, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Instagram Saver', style: AppTypography.menuTitle().copyWith(fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _urlController,
                        style: AppTypography.menuTitle().copyWith(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'https://www.instagram.com/...',
                          prefixIcon: Icon(Icons.link_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SyncPrimaryButton(
                        label: 'DOWNLOAD & SIMPAN',
                        icon: Icons.download_rounded,
                        loading: _isLoading,
                        variant: ButtonVariant.light,
                        onPressed: _downloadInstagram,
                      ),
                    ],
                  ),
                ),
              ),
              if (_mediaData != null) ...[
                const SizedBox(height: 14),
                FadeSlideIn(
                  child: ElegantCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                            const SizedBox(width: 8),
                            Text('Media terdeteksi', style: AppTypography.menuTitle().copyWith(fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_mediaData!['type'] == 'video')
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
                            )
                        else
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Image.network(
                                thumb.isNotEmpty ? thumb : mediaUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => Container(
                                  color: AppColors.dashBg,
                                  child: const Icon(Icons.image_rounded, color: AppColors.dashAccent, size: 48),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        SyncPrimaryButton(
                          label: 'BAGIKAN KONTEN',
                          icon: Icons.share_rounded,
                          loading: _isSharing,
                          variant: ButtonVariant.light,
                          onPressed: _shareContent,
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