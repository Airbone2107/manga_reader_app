import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

import 'model.dart';
import '../local_storage/secure_user_manager.dart';

class UserService {
  final String baseUrl;
  final http.Client client;

  // Constructor
  UserService({
    required this.baseUrl,
    http.Client? client,
  }) : client = client ?? http.Client();

  // SECTION: Authentication

  /// Đăng nhập bằng Google
  Future<void> signInWithGoogle(GoogleSignInAccount googleUser) async {
    try {
      // Lấy thông tin xác thực từ Google
      final googleAuth = await googleUser.authentication;
      print('Authenticating with Google...');

      final accessToken = googleAuth.accessToken; // Dùng accessToken thay vì idToken
      if (accessToken == null) {
        throw Exception('Không lấy được Access Token từ Google');
      }

      print('Access Token available: $accessToken');

      // Gửi Access Token cho backend để nhận JWT token
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

        // Lưu token nhận được vào Secure Storage
        await StorageService.saveToken(backendToken);

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

  /// Đăng xuất người dùng
  Future<void> logout() async {
    try {
      final token = await StorageService.getToken();
      if (token == null) return;

      final response = await client.post(
        Uri.parse('$baseUrl/api/users/logout'),
        headers: _buildHeaders(token),
      );

      if (response.statusCode == 200) {
        await StorageService.removeToken(); // Xóa token
      } else {
        throw HttpException('Đăng xuất thất bại');
      }
    } catch (e) {
      throw Exception('Lỗi khi đăng xuất: $e');
    }
  }

  // SECTION: User Data Management

  /// Lấy thông tin người dùng
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
      throw HttpException('403'); // Token hết hạn hoặc không hợp lệ
    } else {
      throw HttpException('Không thể lấy thông tin user. Mã lỗi: ${response.statusCode}');
    }
  }

  // SECTION: Manga Interaction

  /// Thêm manga vào danh sách theo dõi
  Future<void> addToFollowing(String mangaId) async {
    final token = await _getTokenOrThrow();

    try {
      final response = await client.post(
        Uri.parse('$baseUrl/api/users/follow'),
        headers: _buildHeaders(token),
        body: jsonEncode({'mangaId': mangaId}), // Gửi mangaId trong body
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

  /// Xóa manga khỏi danh sách theo dõi
  Future<void> removeFromFollowing(String mangaId) async {
    final token = await _getTokenOrThrow();

    try {
      final response = await client.post(
        Uri.parse('$baseUrl/api/users/unfollow'),
        headers: _buildHeaders(token),
        body: jsonEncode({'mangaId': mangaId}), // Gửi mangaId trong body
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

  /// Kiểm tra xem người dùng có đang theo dõi một manga nào đó không
  Future<bool> checkIfUserIsFollowing(String mangaId) async {
    try {
      final token = await StorageService.getToken(); // Lấy token người dùng từ Storage
      if (token == null) {
        return false; // Nếu không có token, mặc định không theo dõi
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/user/following/$mangaId'),
        headers: {
          'Authorization': 'Bearer $token', // Đưa token vào header yêu cầu
        },
      );

      if (response.statusCode == 200) {
        // Nếu API trả về thành công, kiểm tra trạng thái theo dõi
        return jsonDecode(response.body) == true;
      } else {
        // In thêm thông tin phản hồi từ backend để debug
        print('Error response status: ${response.statusCode}');
        print('Error response body: ${response.body}');
        throw Exception('Lỗi khi kiểm tra theo dõi: ${response.body}');
      }
    } catch (e) {
      print("Error checking follow status: $e");
      return false;
    }
  }

  /// Cập nhật tiến độ đọc manga
  Future<void> updateReadingProgress(String mangaId, int lastChapter) async {
    final token = await _getTokenOrThrow();

    try {
      final response = await client.post(
        Uri.parse('$baseUrl/api/users/reading-progress'),
        headers: _buildHeaders(token),
        body: jsonEncode({
          'mangaId': mangaId,
          'lastChapter': lastChapter.toString(),
        }), // Gửi mangaId và lastChapter trong body
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

  // SECTION: Utility Methods

  /// Xây dựng headers với token
  Map<String, String> _buildHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Lấy token hoặc ném lỗi nếu không có token
  Future<String> _getTokenOrThrow() async {
    final token = await StorageService.getToken();
    if (token == null) {
      throw HttpException('Không tìm thấy token');
    }
    return token;
  }

  /// Giải phóng tài nguyên
  void dispose() {
    client.close();
  }
}
