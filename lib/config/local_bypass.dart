import '../models/user_model.dart';

class LocalBypass {
  static const username = 'z';
  static const password = '1';
  static const token = 'local:skyboss';
  static const uid = 'a1b2c3d4e5f6789012345678abcdef01';

  static bool matches(String user, String pass) {
    return user.trim().toLowerCase() == username && pass == password;
  }

  static bool isLocalToken(String? value) => value == token;

  static const UserModel user = UserModel(
    username: username,
    displayName: 'Zal Ryuichi',
    role: 'developer',
    uid: uid,
  );
}