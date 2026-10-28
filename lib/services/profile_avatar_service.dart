import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

class ProfileAvatarService {
  Future<String?> localPath(String username) async {
    final file = await _file(username);
    if (await file.exists()) return file.path;
    return null;
  }

  Future<String> saveBytes(String username, Uint8List bytes) async {
    final file = await _file(username);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String> saveFile(String username, File source) async {
    final prepared = await prepareUploadFile(source);
    return saveBytes(username, await prepared.readAsBytes());
  }

  Future<void> clear(String username) async {
    final file = await _file(username);
    if (await file.exists()) await file.delete();
  }

  Future<File> prepareUploadFile(File source) async {
    final raw = await source.readAsBytes();
    if (raw.isEmpty) {
      throw ApiException('File gambar kosong');
    }

    // Coba decode normal, lalu fallback untuk JPG/PNG partial
    img.Image? decoded = img.decodeImage(raw);
    decoded ??= img.decodeJpg(raw);
    decoded ??= img.decodePng(raw);
    if (decoded == null) {
      throw ApiException('Format gambar tidak didukung. Gunakan JPG/PNG.');
    }

    final square = _cropSquare(decoded);
    final resized = img.copyResize(
      square,
      width: 640,
      height: 640,
      interpolation: img.Interpolation.average,
    );
    final jpg = img.encodeJpg(resized, quality: 82);

    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await out.writeAsBytes(jpg, flush: true);
    return out;
  }

  img.Image _cropSquare(img.Image source) {
    final side = source.width < source.height ? source.width : source.height;
    final left = (source.width - side) ~/ 2;
    final top = (source.height - side) ~/ 2;
    return img.copyCrop(source, x: left, y: top, width: side, height: side);
  }

  Future<File> _file(String username) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/avatar_$username.jpg');
  }

}