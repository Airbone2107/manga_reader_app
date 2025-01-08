import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';

  static Future<void> saveToken(String token) async {
    print('Saving token: $token');
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    final token = await _storage.read(key: _tokenKey);
    print('Retrieved token: $token');
    return token;
  }

  static Future<void> removeToken() async {
    print('Removing token...');
    await _storage.delete(key: _tokenKey);
  }

  static Future<bool> hasValidToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> updateToken(String newToken) async {
    await _storage.write(key: _tokenKey, value: newToken);
  }
}
