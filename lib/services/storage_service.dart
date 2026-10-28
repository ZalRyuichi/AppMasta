import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _tokenKey = 'sync_token';
  static const _userKey = 'sync_user';
  static const _deviceKey = 'sync_device_id';
  static const _savedCredsKey = 'sync_saved_creds';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> setToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userKey);
  }

  Future<void> setUsername(String? username) async {
    final prefs = await SharedPreferences.getInstance();
    if (username == null) {
      await prefs.remove(_userKey);
    } else {
      await prefs.setString(_userKey, username);
    }
  }

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_deviceKey);
    if (cached != null && cached.isNotEmpty) return cached;

    String id = '';
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      id = info.id.trim();
    }
    if (id.isEmpty) {
      id = '${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecond}';
    }
    await prefs.setString(_deviceKey, id);
    return id;
  }

  Future<({String username, String password})?> getSavedCreds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedCredsKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(utf8.decode(base64Decode(raw))) as Map<String, dynamic>;
      return (username: map['username'] as String, password: map['password'] as String);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCreds(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = base64Encode(utf8.encode(jsonEncode({
      'username': username,
      'password': password,
    })));
    await prefs.setString(_savedCredsKey, encoded);
  }

  Future<void> clearSavedCreds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedCredsKey);
  }

  Future<void> clearSession() async {
    await setToken(null);
    await setUsername(null);
  }
}