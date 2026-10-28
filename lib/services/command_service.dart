import 'dart:convert';

import 'api_client.dart';

class CommandService {
  CommandService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<void> send({
    required String token,
    required String deviceId,
    required String command,
    dynamic value,
  }) async {
    await _api.postJson(
      '/api/command/$deviceId',
      token: token,
      body: {
        'command': command,
        if (value != null) 'value': _encodeValue(value),
      },
    );
  }

  String _encodeValue(dynamic value) {
    if (value is String) return value;
    if (value is bool || value is num) return value.toString();
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }

  Future<String> fetchScreenshot({
    required String token,
    required String deviceId,
  }) async {
    final data = await _api.getJson('/api/screenshot/$deviceId', token: token);
    final frame = data['frame']?.toString();
    if (frame == null || frame.isEmpty) {
      throw ApiException(data['error']?.toString() ?? 'Belum ada frame kamera');
    }
    return frame;
  }

  Future<List<int>> downloadFile({
    required String token,
    required String deviceId,
    required String path,
  }) async {
    return _api.downloadBytes('/api/file/$deviceId?path=${Uri.encodeComponent(path)}', token: token);
  }
}