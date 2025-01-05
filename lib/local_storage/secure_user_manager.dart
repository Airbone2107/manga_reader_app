import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  // Keys for storage
  static const String _userIdKey = 'user_id';
  static const String _googleIdKey = 'google_id';
  static const String _emailKey = 'email';
  static const String _displayNameKey = 'display_name';
  static const String _photoUrlKey = 'photo_url';
  static const String _createdAtKey = 'created_at';
  static const String _tokenKey = 'auth_token';

  // Lưu thông tin user
  static Future<void> saveUserInfo({
    required String id,
    required String googleId,
    required String email,
    required String displayName,
    required DateTime createdAt, // Thêm createdAt
    String? photoURL,
  }) async {
    await _storage.write(key: _userIdKey, value: id);
    await _storage.write(key: _googleIdKey, value: googleId);
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _displayNameKey, value: displayName);
    await _storage.write(key: _createdAtKey, value: createdAt.toIso8601String());
    if (photoURL != null) {
      await _storage.write(key: _photoUrlKey, value: photoURL);
    }
  }

  // Lấy thông tin user
  static Future<Map<String, String?>> getUserInfo() async {
    final createdAtStr = await _storage.read(key: _createdAtKey);
    return {
      'id': await _storage.read(key: _userIdKey),
      'googleId': await _storage.read(key: _googleIdKey),
      'email': await _storage.read(key: _emailKey),
      'displayName': await _storage.read(key: _displayNameKey),
      'photoURL': await _storage.read(key: _photoUrlKey) ?? null,
      'createdAt': createdAtStr,
    };
  }

  // Cập nhật method clearAll
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Kiểm tra xem user đã đăng nhập chưa
  static Future<bool> isLoggedIn() async {
    final userId = await _storage.read(key: _userIdKey);
    return userId != null;
  }

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> removeToken() async {
    await _storage.delete(key: _tokenKey);
  }
}
