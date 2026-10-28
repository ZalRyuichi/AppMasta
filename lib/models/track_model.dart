class TrackModel {
  const TrackModel({
    required this.id,
    required this.name,
    required this.artistName,
    required this.albumName,
    required this.duration,
    required this.audioUrl,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String artistName;
  final String albumName;
  final int duration; // seconds
  final String audioUrl;
  final String imageUrl;

  String get durationLabel {
    final m = duration ~/ 60;
    final s = duration % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Parsing generik untuk hasil pencarian musik (endpoint ytplay).
  /// Dibuat fleksibel karena nama field tiap provider bisa berbeda-beda.
  factory TrackModel.fromApi(Map<String, dynamic> json) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    String pickUrl(List<String> keys) {
      for (final k in keys) {
        final u = _extractUrl(json[k]);
        if (u != null) return u;
      }
      return '';
    }

    final id = pick(['id', 'videoId', 'video_id']);
    final title = pick(['title', 'judul', 'name']);
    final author = pick(['author', 'channel', 'artist', 'artist_name', 'uploader']);
    final audio = pickUrl(['url', 'audio', 'formats', 'media', 'download', 'downloadUrl', 'download_url', 'link', 'audio_url']);
    final image = pickUrl(['thumbnail', 'image', 'thumb', 'cover']);

    return TrackModel(
      id: id.isNotEmpty ? id : audio,
      name: title.isNotEmpty ? title : 'Unknown',
      artistName: author.isNotEmpty ? author : 'Unknown Artist',
      albumName: '',
      duration: _parseDuration(json['duration']),
      audioUrl: audio,
      imageUrl: image,
    );
  }

  /// Field media dari API bisa berupa String URL langsung, Map berisi
  /// {quality, url}, atau List berisi beberapa opsi kualitas seperti itu.
  /// Fungsi ini menggali sampai ketemu String URL yang valid.
  static String? _extractUrl(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final s = v.trim();
      return s.isNotEmpty && Uri.tryParse(s)?.hasScheme == true ? s : null;
    }
    if (v is Map) {
      return _extractUrl(v['url'] ?? v['link'] ?? v['download']);
    }
    if (v is List) {
      for (final item in v) {
        final u = _extractUrl(item);
        if (u != null) return u;
      }
    }
    return null;
  }

  static int _parseDuration(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw.toInt();
    final s = raw.toString().trim();
    if (s.isEmpty) return 0;
    final asInt = int.tryParse(s);
    if (asInt != null) return asInt;
    // Format "mm:ss" atau "hh:mm:ss"
    final parts = s.split(':').map((e) => int.tryParse(e) ?? 0).toList();
    var seconds = 0;
    for (final p in parts) {
      seconds = seconds * 60 + p;
    }
    return seconds;
  }
}
