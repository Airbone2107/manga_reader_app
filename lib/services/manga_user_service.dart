import 'dart:convert';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'model.dart';

class UserService {
  final String baseUrl;
  final http.Client client;

  UserService({
    required this.baseUrl,
    http.Client? client,
  }) : client = client ?? http.Client();

  void dispose() {
    client.close();
  }
  Future<void> removeFromFollowing(String userId, String mangaId) async {
    try {
      final response = await client.delete(
        Uri.parse('$baseUrl/api/users/following/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mangaId': mangaId}),
      );

      if (response.statusCode != 200) {
        throw Exception('Không thể bỏ theo dõi truyện');
      }
    } catch (e) {
      throw Exception('Lỗi khi bỏ theo dõi: $e');
    }
  }
  // Đăng nhập với Google
  Future<User> signInWithGoogle(GoogleSignInAccount googleUser) async {
    try {
      print('Sending request to: $baseUrl/api/users/auth/google');
      print('Request data: ${googleUser.id}, ${googleUser.email}, ${googleUser.displayName}');

      final response = await client.post(
        Uri.parse('$baseUrl/api/users/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'googleId': googleUser.id,
          'email': googleUser.email,
          'displayName': googleUser.displayName,
          'photoURL': googleUser.photoUrl,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        return User.fromJson(userData);
      } else {
        throw HttpException('Đăng nhập thất bại: ${response.statusCode}\nBody: ${response.body}');
      }
    } catch (e) {
      print('Error in signInWithGoogle: $e');
      throw Exception('Lỗi đăng nhập: $e');
    }
  }

  // Thêm manga vào danh sách theo dõi
  Future<void> addToFollowing(String userId, String mangaId) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/api/users/following/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mangaId': mangaId}),
      );

      if (response.statusCode != 200) {
        throw HttpException('Không thể thêm vào danh sách theo dõi');
      }
    } catch (e) {
      throw Exception('Lỗi khi thêm manga: $e');
    }
  }

  // Cập nhật tiến độ đọc
  Future<void> updateReadingProgress(
    String userId,
    String mangaId,
    int lastChapter,
  ) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/api/users/reading/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mangaId': mangaId,
          'lastChapter': lastChapter,
        }),
      );

      if (response.statusCode != 200) {
        throw HttpException('Không thể cập nhật tiến độ đọc');
      }
    } catch (e) {
      throw Exception('Lỗi khi cập nhật tiến độ: $e');
    }
  }
}
