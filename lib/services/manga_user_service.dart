import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

import 'model.dart';
import '../local_storage/secure_user_manager.dart';

class UserService {
  // Các thuộc tính của class
  final String baseUrl;
  final http.Client client;
  String? _token;

  // Constructor
  UserService({
    required this.baseUrl,
    http.Client? client,
  }) : client = client ?? http.Client();

  // SECTION: Token Management
  //--------------------------------------------

  /// Khởi tạo token từ secure storage
  Future<void> initToken() async {
    _token = await StorageService.getToken();
  }

  /// Getter cho token
  String? get token => _token;

  /// Kiểm tra tính hợp lệ của token
  Future<bool> isTokenValid() async {
    if (_token == null) return false;
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/api/users/verify-token'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Làm mới token từ storage
  Future<void> refreshToken() async {
    _token = await StorageService.getToken();
  }

  // SECTION: Authentication
  //--------------------------------------------

  /// Đăng nhập bằng Google
  Future<User> signInWithGoogle(GoogleSignInAccount googleUser) async {
    try {
      final googleAuth = await googleUser.authentication;
      print('Authenticating with Google...');

      final accessToken = googleAuth.accessToken;
      print('Access Token available: ${accessToken != null}');

      // Chỉ gửi access token
      final response = await client.post(
        Uri.parse('$baseUrl/api/users/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': googleUser.email,
          'displayName': googleUser.displayName,
          'photoURL': googleUser.photoUrl,
          'accessToken': accessToken,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        await StorageService.saveToken(_token!);

        final user = User.fromJson(data['user']);
        await StorageService.saveUserInfo(
          id: user.id,
          googleId: user.googleId,
          email: user.email,
          displayName: user.displayName,
          photoURL: user.photoURL,
          createdAt: user.createdAt,
        );

        return user;
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
      if (_token == null) return;

      final response = await client.post(
        Uri.parse('$baseUrl/api/users/logout'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        _token = null;
        await StorageService.clearAll();
      } else {
        throw HttpException('Đăng xuất thất bại');
      }
    } catch (e) {
      throw Exception('Lỗi khi đăng xuất: $e');
    }
  }

  // SECTION: User Data Management
  //--------------------------------------------

  /// Lấy thông tin người dùng
  Future<User> getUserData(String userId) async {
    try {
      final response = await _handleResponse(() => client.get(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: _headers,
      ));

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        return User.fromJson(userData);
      } else {
        throw HttpException('Không thể lấy thông tin user');
      }
    } catch (e) {
      throw Exception('Lỗi khi lấy thông tin user: $e');
    }
  }

  // SECTION: Manga Interaction
  //--------------------------------------------

  /// Thêm manga vào danh sách theo dõi
  Future<void> addToFollowing(String userId, String mangaId) async {
    try {
      await _ensureValidToken(); // Kiểm tra token trước khi gọi API

      final response = await client.post(
        // Đổi từ GET sang POST
        Uri.parse('$baseUrl/api/users/$userId/follow')
            .replace(queryParameters: {'mangaId': mangaId}),
        headers: _headers,
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
  Future<void> removeFromFollowing(String userId, String mangaId) async {
    try {
      await _ensureValidToken(); // Kiểm tra token trước khi gọi API

      final response = await client.post(
        Uri.parse('$baseUrl/api/users/$userId/unfollow')
            .replace(queryParameters: {'mangaId': mangaId}),
        headers: _headers,
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

  /// Cập nhật tiến độ đọc manga
  Future<void> updateReadingProgress(String userId, String mangaId, int lastChapter) async {
    try {
      await _ensureValidToken(); // Kiểm tra token trước khi gọi API

      final response = await client.post(
        // Đổi từ GET sang POST
        Uri.parse('$baseUrl/api/users/$userId/reading-progress')
            .replace(queryParameters: {
          'mangaId': mangaId,
          'lastChapter': lastChapter.toString(),
        }),
        headers: _headers,
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
  //--------------------------------------------

  /// Headers cho HTTP requests
  Map<String, String> get _headers {
    if (_token == null) {
      throw HttpException('Không tìm thấy token');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };
  }

  /// Đảm bảo token hợp lệ trước khi thực hiện request
  Future<void> _ensureValidToken() async {
    if (_token == null) {
      _token = await StorageService.getToken();
      if (_token == null) {
        throw HttpException('Không tìm thấy token');
      }
    }
  }


  /// Kiểm tra trạng thái đăng nhập
  Future<bool> isLoggedIn() async {
    return await StorageService.isLoggedIn();
  }

  /// Xử lý response từ API
  Future<dynamic> _handleResponse(Future<http.Response> Function() request) async {
    try {
      final response = await request();

      if (response.statusCode == 401) {
        // Token hết hạn hoặc không hợp lệ
        await logout();
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }

      return response;
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  /// Giải phóng tài nguyên
  void dispose() {
    client.close();
  }
}
