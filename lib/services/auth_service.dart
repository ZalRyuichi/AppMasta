import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../config/local_bypass.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'profile_avatar_service.dart';
import 'storage_service.dart';

class AuthService extends ChangeNotifier {
  AuthService({ApiClient? api, StorageService? storage, ProfileAvatarService? avatars})
      : _api = api ?? ApiClient(),
        _storage = storage ?? StorageService(),
        _avatars = avatars ?? ProfileAvatarService();

  final ApiClient _api;
  final StorageService _storage;
  final ProfileAvatarService _avatars;
  final _picker = ImagePicker();

  String? token;
  UserModel? user;
  String? avatarPath;
  bool loading = false;
  bool avatarLoading = false;

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  Future<void> _syncDeviceId() async {
    final deviceId = await _storage.getOrCreateDeviceId();
    _api.setDeviceId(deviceId);
  }

  Future<void> bootstrap() async {
    await _syncDeviceId();
    token = await _storage.getToken();
    if (token != null) {
      if (LocalBypass.isLocalToken(token)) {
        user = LocalBypass.user;
        await _hydrateAvatar();
        notifyListeners();
        return;
      }
      try {
        final data = await _api.getJson('/api/me', token: token);
        user = UserModel.fromJson(data);
        await _hydrateAvatar();
      } catch (_) {
        await _storage.clearSession();
        token = null;
        user = null;
        avatarPath = null;
      }
    }
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    loading = true;
    notifyListeners();
    try {
      await _syncDeviceId();
      final deviceId = await _storage.getOrCreateDeviceId();
      ApiException? serverError;
      var networkFail = false;

      try {
        final data = await _api.postJson('/api/login', body: {
          'username': username.trim(),
          'password': password,
          'deviceId': deviceId,
        });
        if (data['ok'] == true) {
          token = data['token']?.toString();
          await _storage.setToken(token);
          await _storage.setUsername(data['username']?.toString() ?? username);
          final me = await _api.getJson('/api/me', token: token);
          user = UserModel.fromJson(me);
          await _hydrateAvatar();
          return;
        }
        serverError = ApiException(data['error']?.toString() ?? 'Login gagal');
      } on ApiException catch (e) {
        serverError = e;
      } catch (_) {
        networkFail = true;
      }

      final errMsg = serverError?.message ?? '';
      final wrongPassword = serverError != null &&
          RegExp(r'salah|wrong|password', caseSensitive: false).hasMatch(errMsg);

      if (LocalBypass.matches(username, password) && !wrongPassword && (networkFail || serverError == null)) {
        token = LocalBypass.token;
        user = LocalBypass.user;
        await _storage.setToken(token);
        await _storage.setUsername(user!.displayName);
        await _hydrateAvatar();
        return;
      }

      throw serverError ?? ApiException('Login gagal · server tidak terjangkau');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout({bool silent = false}) async {
    try {
      if (token != null && !LocalBypass.isLocalToken(token)) {
        await _api.postJson('/api/logout', token: token);
      }
    } catch (_) {}
    await _storage.clearSession();
    token = null;
    user = null;
    avatarPath = null;
    if (!silent) notifyListeners();
  }

  Future<void> refreshMe() async {
    if (token == null) return;
    if (LocalBypass.isLocalToken(token)) {
      user = LocalBypass.user;
      await _hydrateAvatar();
      notifyListeners();
      return;
    }
    final data = await _api.getJson('/api/me', token: token);
    user = UserModel.fromJson(data);
    await _hydrateAvatar();
    notifyListeners();
  }

  Future<void> pickAndUploadAvatar(ImageSource source) async {
    if (token == null || user == null) {
      throw ApiException('Sesi login tidak valid');
    }

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null) return;

    avatarLoading = true;
    notifyListeners();
    try {
      final prepared = await _avatars.prepareUploadFile(File(picked.path));
      // Local bypass: simpan foto lokal saja (tanpa server)
      if (LocalBypass.isLocalToken(token)) {
        avatarPath = await _avatars.saveFile(user!.username, prepared);
        user = user!.copyWith(hasAvatar: true);
        return;
      }
      await _api.uploadAvatar(token: token!, file: prepared);
      avatarPath = await _avatars.saveFile(user!.username, prepared);
      user = user!.copyWith(hasAvatar: true);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Gagal upload foto: $e');
    } finally {
      avatarLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeAvatar() async {
    if (token == null || user == null) {
      throw ApiException('Sesi login tidak valid');
    }
    avatarLoading = true;
    notifyListeners();
    try {
      if (!LocalBypass.isLocalToken(token)) {
        await _api.deleteJson('/api/profile-avatar', token: token);
      }
      await _avatars.clear(user!.username);
      avatarPath = null;
      user = user!.copyWith(hasAvatar: false);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Gagal hapus foto: $e');
    } finally {
      avatarLoading = false;
      notifyListeners();
    }
  }

  Future<void> _hydrateAvatar() async {
    final current = user;
    if (current == null) {
      avatarPath = null;
      return;
    }

    avatarPath = await _avatars.localPath(current.username);
    if (!current.hasAvatar) {
      if (avatarPath != null) {
        await _avatars.clear(current.username);
        avatarPath = null;
      }
      return;
    }

    if (avatarPath != null) return;

    try {
      final bytes = await _api.getAvatarBytes(token: token!);
      if (bytes != null) {
        avatarPath = await _avatars.saveBytes(current.username, bytes);
      }
    } catch (_) {}
  }
}