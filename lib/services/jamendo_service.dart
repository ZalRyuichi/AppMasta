import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/track_model.dart';

/// Music search service — pakai endpoint ytplay (search YouTube + ambil link
/// play), tanpa API key.
class JamendoService {
  const JamendoService();

  static const _base = 'https://api.ikyyxd.my.id/search/ytplay';

  Future<List<TrackModel>> searchTracks(
    String query, {
    int limit = 20,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final uri = Uri.parse(_base).replace(queryParameters: {'q': q});
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode >= 400) {
      throw Exception('Music API HTTP ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);
    return _parseTracks(decoded).take(limit).toList();
  }

  /// Tidak ada endpoint "trending" di API ini, jadi "populer" memakai
  /// pencarian dengan kata kunci default.
  Future<List<TrackModel>> popularTracks({int limit = 15}) {
    return searchTracks('lagu populer', limit: limit);
  }

  List<TrackModel> _parseTracks(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return const [];

    final status = decoded['status'];
    if (status == false) {
      final msg = decoded['msg'] ?? decoded['message'];
      throw Exception('Music API: ${msg ?? 'gagal mengambil data'}');
    }

    final raw = decoded['result'] ?? decoded['data'] ?? decoded['results'];

    // Bisa berupa satu objek (search + play digabung) atau daftar hasil.
    final items = raw is List
        ? raw
        : (raw is Map<String, dynamic> ? [raw] : const []);

    return items
        .whereType<Map>()
        .map((e) => TrackModel.fromApi(Map<String, dynamic>.from(e)))
        .where((t) => t.audioUrl.isNotEmpty)
        .toList();
  }
}
