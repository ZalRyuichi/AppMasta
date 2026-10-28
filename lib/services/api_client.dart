import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';

class ApiClient {
  ApiClient({String? baseUrl}) : _override = baseUrl;

  final String? _override;
  String? _deviceId;

  String get _base => _override ?? ApiConfig.baseUrl;

  void setDeviceId(String? deviceId) {
    final v = deviceId?.trim();
    _deviceId = (v == null || v.isEmpty) ? null : v;
  }

  Map<String, String> _headers({String? token, bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
        if (token != null) 'x-auth-token': token,
        if (_deviceId != null) 'x-device-id': _deviceId!,
      };

  Uri _uri(String path) => Uri.parse('$_base$path');

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final res = await http
        .post(
          _uri(path),
          headers: _headers(token: token, json: true),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    final res = await http
        .get(
          _uri(path),
          headers: _headers(token: token),
        )
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<dynamic> getRaw(String path, {String? token}) async {
    final res = await http
        .get(
          _uri(path),
          headers: _headers(token: token),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode >= 400) {
      throw ApiException('Request gagal (${res.statusCode})', statusCode: res.statusCode);
    }
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) async {
    final res = await http
        .delete(
          _uri(path),
          headers: _headers(token: token),
        )
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Uint8List> downloadBytes(String path, {String? token}) async {
    final res = await http
        .get(
          _uri(path),
          headers: _headers(token: token),
        )
        .timeout(const Duration(seconds: 45));
    if (res.statusCode >= 400) {
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      throw ApiException(
        data['error']?.toString() ?? 'Download gagal (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    return res.bodyBytes;
  }

  Future<Uint8List?> getAvatarBytes({required String token}) async {
    final res = await http
        .get(
          _uri('/api/profile/avatar'),
          headers: _headers(token: token),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 404) return null;
    if (res.statusCode >= 400) {
      throw ApiException('Gagal memuat foto profil (${res.statusCode})', statusCode: res.statusCode);
    }
    return res.bodyBytes;
  }

  Future<Map<String, dynamic>> uploadAvatar({
    required String token,
    required File file,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/api/profile-avatar'));
    req.headers.addAll(_headers(token: token));
    // Always send proper image/* content-type so server accepts the file
    req.files.add(await _imageMultipart(file, field: 'avatar'));
    final streamed = await req.send().timeout(const Duration(seconds: 45));
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }

  Future<Map<String, dynamic>> uploadProof({
    required String depositId,
    required File file,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/api/deposit/upload-proof'));
    req.fields['deposit_id'] = depositId;
    req.files.add(await _imageMultipart(file));
    final streamed = await req.send().timeout(const Duration(seconds: 45));
    final res = await http.Response.fromStream(streamed);
    return _decodeDeposit(res);
  }

  Future<Map<String, dynamic>> submitDeposit({
    required String role,
    required String username,
    required String password,
    required File proof,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/api/deposit/submit'));
    req.fields['role'] = role;
    req.fields['username'] = username;
    req.fields['password'] = password;
    req.files.add(await _imageMultipart(proof));
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    return _decodeDeposit(res);
  }

  Future<Map<String, dynamic>> submitDepositDual({
    required String role,
    required String username,
    required String password,
    required File proofBuyer,
    required File proofFee,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/api/deposit/submit-dual'));
    req.fields['role']     = role;
    req.fields['username'] = username;
    req.fields['password'] = password;
    req.files.add(await _imageMultipart(proofBuyer, field: 'proof_buyer'));
    req.files.add(await _imageMultipart(proofFee,   field: 'proof_fee'));
    final streamed = await req.send().timeout(const Duration(seconds: 90));
    final res = await http.Response.fromStream(streamed);
    return _decodeDeposit(res);
  }

  Future<Map<String, dynamic>> getSellerStoranPaymentInfo() async {
    return getJson('/api/seller-storan/payment-info');
  }

  Future<Map<String, dynamic>> getSellerCreatableRoles({required String token}) async {
    return getJson('/api/seller-storan/creatable-roles', token: token);
  }

  Future<Map<String, dynamic>> submitSellerStoran({
    required String token,
    required String role,
    required String username,
    required String password,
    required String trialDuration,
    required File proofBuyer,
    required File proofFee,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/api/seller-storan/submit'));
    req.headers.addAll(_headers(token: token));
    req.fields['role'] = role;
    req.fields['username'] = username;
    req.fields['password'] = password;
    req.fields['trialDuration'] = trialDuration;
    req.files.add(await _imageMultipart(proofBuyer, field: 'proof_buyer'));
    req.files.add(await _imageMultipart(proofFee, field: 'proof_fee'));
    final streamed = await req.send().timeout(const Duration(seconds: 90));
    final res = await http.Response.fromStream(streamed);
    return _decodeDeposit(res);
  }

  Future<http.MultipartFile> _imageMultipart(File file, {String field = 'proof'}) async {
    final rawName = file.path.split(Platform.pathSeparator).last;
    final filename = rawName.isEmpty ? 'proof.jpg' : rawName;
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'jpg';
    final contentType = switch (ext) {
      'png'  => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'gif'  => MediaType('image', 'gif'),
      'heic' => MediaType('image', 'heic'),
      'heif' => MediaType('image', 'heif'),
      _      => MediaType('image', 'jpeg'),
    };

    if (await file.exists()) {
      return http.MultipartFile.fromPath(
        field,
        file.path,
        filename: filename,
        contentType: contentType,
      );
    }

    final bytes = await file.readAsBytes();
    return http.MultipartFile.fromBytes(
      field,
      bytes,
      filename: filename,
      contentType: contentType,
    );
  }

  Map<String, dynamic> _decodeDeposit(http.Response res) {
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      data = {'error': res.body.isEmpty ? 'Server error' : res.body};
    }
    if (res.statusCode >= 400) {
      throw ApiException(
        data['error']?.toString() ?? 'Request gagal (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    if (data['success'] == false) {
      throw ApiException(data['error']?.toString() ?? 'Request gagal');
    }
    return data;
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      data = {'error': res.body.isEmpty ? 'Server error' : res.body};
    }
    if (res.statusCode >= 400) {
      throw ApiException(
        data['error']?.toString() ?? 'Request gagal (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    return data;
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
