import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String configUrl = String.fromEnvironment(
    'SYNC_CONFIG_URL',
    defaultValue: 'https://raw.githubusercontent.com/ZalRyuichi/MastaRAT/main/api.json',
  );

  static const String _buildOverride = String.fromEnvironment('SYNC_API_URL');
  static const String _debugLocalUrl = 'http://dikzmarket.pteroq.biz.id:3429';
  static const _cacheKey = 'sync_api_base_url';

  static String _baseUrl = '';
  static bool _ready = false;
  static String? _lastError;
  static bool _fromRemote = false;

  static String get baseUrl => _baseUrl;
  static String get socketUrl => _baseUrl;
  static bool get isReady => _ready;
  static String? get lastError => _lastError;
  static bool get fromRemote => _fromRemote;

  static Future<void> initialize() async {
    if (_ready) return;

    final prefs = await SharedPreferences.getInstance();
    var cached = prefs.getString(_cacheKey);
    if (cached != null && _isLocalOnlyUrl(cached)) {
      await prefs.remove(_cacheKey);
      cached = null;
    }

    if (_buildOverride.isNotEmpty) {
      _setUrl(_normalize(_buildOverride), remote: false);
      _ready = true;
      return;
    }

    try {
      final remote = await _fetchRemoteBaseUrl();
      if (await _probe(remote)) {
        await _setUrl(remote, remote: true, prefs: prefs);
        _ready = true;
        return;
      }
      _lastError = 'Server VPS tidak merespons: $remote';
    } catch (e) {
      _lastError = e.toString();
    }

    if (cached != null && cached.isNotEmpty) {
      final url = _normalize(cached);
      if (await _probe(url)) {
        await _setUrl(url, remote: false, prefs: prefs);
        _ready = true;
        return;
      }
    }

    if (kDebugMode && await _probe(_debugLocalUrl)) {
      await _setUrl(_debugLocalUrl, remote: false, prefs: prefs);
      _ready = true;
      return;
    }

    try {
      _baseUrl = await _fetchRemoteBaseUrl();
      _fromRemote = true;
    } catch (_) {
      _baseUrl = _normalize(cached ?? '');
    }
    _ready = true;
  }

  static Future<void> _setUrl(
    String url, {
    required bool remote,
    SharedPreferences? prefs,
  }) async {
    _baseUrl = url;
    _fromRemote = remote;
    _lastError = null;
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.setString(_cacheKey, url);
  }

  static bool _isLocalOnlyUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('127.0.0.1') ||
        lower.contains('localhost') ||
        lower.contains('10.0.2.2');
  }

  static Future<bool> _probe(String base) async {
    if (base.isEmpty) return false;
    final paths = ['/api/config', '/api/deposit/payment-info', '/api/login'];
    for (final path in paths) {
      try {
        final res = await http.get(Uri.parse('$base$path')).timeout(const Duration(seconds: 4));
        if (res.statusCode < 500) return true;
      } catch (_) {}
    }
    return false;
  }

  static Future<String> _fetchRemoteBaseUrl() async {
    final uri = Uri.parse(configUrl);
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode >= 400) {
      throw Exception('Config GitHub HTTP ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Format api.json tidak valid');
    }

    final raw = data['baseUrl']?.toString().trim() ?? '';
    if (raw.isEmpty) throw Exception('baseUrl kosong di api.json');
    return _normalize(raw);
  }

  static String _normalize(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}