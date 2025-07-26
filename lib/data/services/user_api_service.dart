// lib/data/services/user_api_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import '../../config/app_config.dart'; // Import config
import '../models/user_model.dart';
import '../storage/secure_storage_service.dart';

class UserApiService {
  final String baseUrl;
  final http.Client client;

  // Sử dụng AppConfig.baseUrl làm giá trị mặc định
  UserApiService({
    this.baseUrl = AppConfig.baseUrl,
    http.Client? client,
  }) : client = client ?? http.Client();

  Future<void> signInWithGoogle(GoogleSignInAccount googleUser) async {
    try {
      final googleAuth = await googleUser.authentication;
      print('Authenticating with Google...');

      final accessToken = googleAuth.accessToken;
      if (accessToken == null) {
        throw Exception('Không lấy được Access Token từ Google');
      }

      print('Access Token available: $accessToken');

      final response = await client.post(
        Uri.parse('$baseUrl/api/users/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'accessToken': accessToken}),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final backendToken = data['token'];
        await SecureStorageService.saveToken(backendToken);
        print('Đăng nhập thành công. Token từ backend: $backendToken');
      } else {
        throw HttpException(
            'Đăng nhập thất bại: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error in signInWithGoogle: $e');
      throw Exception('Lỗi đăng nhập: $e');
    }
  }

  Future<void> logout() async {
    try {
      final token = await SecureStorageService.getToken();
      if (token == null) return;

      final response = await client.post(
        Uri.parse('$baseUrl/api/users/logout'),
        headers: _buildHeaders(token),
      );

      if (response.statusCode == 200) {
        await SecureStorageService.removeToken();
      } else {
        throw HttpException('Đăng xuất thất bại');
      }
    } catch (e) {
      throw Exception('Lỗi khi đăng xuất: $e');
    }
  }

  Future<User> getUserData() async {
    final token = await _getTokenOrThrow();
    print("getUserData đang xử lý, token hiện tại là: $token");

    final response = await client.get(
      Uri.parse('$baseUrl/api/users'),
      headers: _buildHeaders(token),
    );
    print("getUserData đã xử lý xong");
    if (response.statusCode == 200) {
      final userData = jsonDecode(response.body);
      return User.fromJson(userData);
    } else if (response.statusCode == 403) {
      throw HttpException('403');
    } else {
      throw HttpException(
          'Không thể lấy thông tin user. Mã lỗi: ${response.statusCode}');
    }
  }

  Future<void> addToFollowing(String mangaId) async {
    final token = await _getTokenOrThrow();
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/api/users/follow'),
        headers: _buildHeaders(token),
        body: jsonEncode({'mangaId': mangaId}),
      );
      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw HttpException(
            error['message'] ?? 'Không thể thêm vào danh sách theo dõi');
      }
    } catch (e) {
      print('Error in addToFollowing: $e');
      throw Exception('Lỗi khi thêm manga: $e');
    }
  }

  Future<void> removeFromFollowing(String mangaId) async {
    final token = await _getTokenOrThrow();
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/api/users/unfollow'),
        headers: _buildHeaders(token),
        body: jsonEncode({'mangaId': mangaId}),
      );
      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw HttpException(error['message'] ?? 'Không thể bỏ theo dõi truyện');
      }
    } catch (e) {
      print('Error in removeFromFollowing: $e');
      throw Exception('Lỗi khi bỏ theo dõi: $e');
    }
  }

  Future<bool> checkIfUserIsFollowing(String mangaId) async {
    try {
      final token = await SecureStorageService.getToken();
      if (token == null) {
        return false;
      }
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/user/following/$mangaId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) == true;
      } else {
        print('Error response status: ${response.statusCode}');
        print('Error response body: ${response.body}');
        throw Exception('Lỗi khi kiểm tra theo dõi: ${response.body}');
      }
    } catch (e) {
      print("Error checking follow status: $e");
      return false;
    }
  }

  Future<void> updateReadingProgress(String mangaId, String lastChapter) async {
    final token = await _getTokenOrThrow();
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/api/users/reading-progress'),
        headers: _buildHeaders(token),
        body: jsonEncode({
          'mangaId': mangaId,
          'lastChapter': lastChapter,
        }),
      );
      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw HttpException(
            error['message'] ?? 'Không thể cập nhật tiến độ đọc');
      }
    } catch (e) {
      print('Error in updateReadingProgress: $e');
      throw Exception('Lỗi khi cập nhật tiến độ: $e');
    }
  }

  Map<String, String> _buildHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<String> _getTokenOrThrow() async {
    final token = await SecureStorageService.getToken();
    if (token == null) {
      throw HttpException('Không tìm thấy token');
    }
    return token;
  }

  void dispose() {
    client.close();
  }
}
