// Thư viện Flutter và các gói cần thiết
import 'dart:io';

import 'package:flutter/material.dart'; // Thư viện Flutter chính
import 'package:google_sign_in/google_sign_in.dart'; // Thư viện đăng nhập Google

// Các class xử lý liên quan đến lưu trữ và dịch vụ người dùng
import '../../local_storage/secure_user_manager.dart'; // Quản lý dữ liệu người dùng an toàn
import '../../services/manga_dex_service.dart';
import '../../services/manga_user_service.dart'; // Dịch vụ xử lý người dùng
import '../../services/model.dart';
import '../detail_manga/manga_detail_screen.dart'; // Mô hình dữ liệu cho ứng dụng

/// Logic xử lý cho màn hình tài khoản người dùng.
class AccountScreenLogic {
  // Khởi tạo các dịch vụ và biến cần thiết
  final MangaDexService _mangaDexService = MangaDexService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    signInOption: SignInOption.standard,
  );
  final UserService _userService = UserService(
    baseUrl: 'https://manga-reader-app-backend.onrender.com',
  );

  final Map<String, dynamic> _mangaCache = {};

  // Các biến trạng thái
  User? user;
  bool isLoading = false;
  late BuildContext context;
  late VoidCallback refreshUI;

  // ----------------------------
  // 1. Các hàm khởi tạo và hủy tài nguyên
  // ----------------------------

  /// Khởi tạo logic màn hình với ngữ cảnh và hàm callback cập nhật giao diện.
  Future<void> init(BuildContext context, VoidCallback refreshUI) async {
    this.context = context;
    this.refreshUI = refreshUI;

    try {
      user = await _fetchUserData();
      refreshUI();
    } on HttpException catch (e) {
      if (e.message == '403') {
        try {
          await handleSignIn();
        } catch (signInError) {
          user = null;
          refreshUI();
        }
      } else {
        print('Lỗi khác trong init: ${e.message}');
      }
    } catch (e) {
      print('Lỗi không xác định trong init: $e');
    }
  }

  /// Hủy logic và giải phóng tài nguyên.
  void dispose() {
    _userService.dispose();
  }

  // ----------------------------
  // 2. Xử lý đăng nhập và đăng xuất
  // ----------------------------

  /// Xử lý đăng nhập Google khi người dùng nhấn nút đăng nhập.
  Future<void> handleSignIn() async {
    try {
      isLoading = true;
      refreshUI();

      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw Exception('Đăng nhập bị hủy');
      }

      await _userService.signInWithGoogle(account);
      user = await _fetchUserData();

      isLoading = false;
      refreshUI();
    } catch (error) {
      print('Lỗi đăng nhập: $error');
      isLoading = false;
      refreshUI();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đăng nhập: $error')),
      );
    }
  }
  /// Xử lý đăng xuất người dùng.
  Future<void> handleSignOut() async {
    try {
      await _userService.logout();
      await _googleSignIn.signOut();
      await StorageService.removeToken();
      user = null;
      refreshUI();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đăng xuất: $error')),
      );
    }
  }

  // ----------------------------
  // 3. Xử lý dữ liệu người dùng
  // ----------------------------

  /// Làm mới dữ liệu người dùng từ API nếu đang đăng nhập.
  Future<void> refreshUserData() async {
    try {
      user = await _fetchUserData();
      refreshUI();
    } catch (e) {
      print('Lỗi khi refresh dữ liệu người dùng: $e');
    }
  }

  /// Lấy thông tin người dùng từ API và trả về một User object.
  Future<User> _fetchUserData() async {
    try {
      print("Đang lấy dữ liệu người dùng...");
      final userData = await _userService.getUserData();
      print("Dữ liệu người dùng đã tải thành công");
      return userData;
    } on HttpException catch (e) {
      if (e.message == '403') {
        throw HttpException('403');
      } else {
        throw HttpException('Lỗi không xác định khi lấy dữ liệu người dùng: ${e.message}');
      }
    } catch (e) {
      throw Exception('Lỗi khi tải dữ liệu người dùng: $e');
    }
  }



  // ----------------------------
  // 4. Xử lý danh sách truyện và UI
  // ----------------------------

  /// Xử lý bỏ theo dõi một truyện.
  Future<void> handleUnfollow(String mangaId) async {
    try {
      if (user == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }

      isLoading = true;
      refreshUI();

      await _userService.removeFromFollowing(mangaId);
      user = await _fetchUserData();

      isLoading = false;
      refreshUI();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã bỏ theo dõi truyện')),
      );
    } catch (e) {
      isLoading = false;
      refreshUI();
      print('Error in handleUnfollow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi bỏ theo dõi: $e')),
      );
    }
  }

  /// Lấy thông tin danh sách manga.
  Future<List<Map<String, dynamic>>> _getMangaListInfo(List<String> mangaIds) async {
    try {
      final List<dynamic> mangas = await _mangaDexService.fetchMangaByIds(mangaIds);
      for (var manga in mangas) {
        _mangaCache[manga['id']] = manga;
      }
      return mangas.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Lỗi khi lấy thông tin danh sách manga: $e');
      return [];
    }
  }

  /// Xây dựng widget hiển thị danh sách manga.
  Widget buildMangaListView(String title, List<String> mangaIds, {bool isFollowing = false}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getMangaListInfo(mangaIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('Lỗi: ${snapshot.error}');
        }

        final mangas = snapshot.data ?? [];
        if (mangas.isEmpty) {
          return Card(
            margin: EdgeInsets.all(8),
            child: ListTile(
              title: Text(title),
              subtitle: Text('Không có dữ liệu'),
            ),
          );
        }

        return Card(
          margin: EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: mangas.length,
                itemBuilder: (context, index) {
                  final manga = mangas[index];
                  return _buildMangaListItem(
                    manga,
                    isFollowing: isFollowing,
                    mangaId: mangaIds[index],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Xây dựng widget cho một mục manga trong danh sách.
  Widget _buildMangaListItem(Map<String, dynamic> manga, {bool isFollowing = false, required String mangaId}) {
    final title = manga['attributes']?['title']?['en'] ?? 'Không có tiêu đề';
    final description = manga['attributes']?['description']?['en'] ?? 'Không có mô tả';
    List<String> tags = (manga['attributes']['tags'] ?? [])
        .where((tag) => tag['attributes']?['name']?['en'] is String)
        .map<String>((tag) => tag['attributes']['name']['en'] as String)
        .toList();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MangaDetailScreen(mangaId: mangaId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12.0),
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 6.0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ảnh bìa manga
            Container(
              width: 80,
              height: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
                child: FutureBuilder<String>(
                  future: _mangaDexService.fetchCoverUrl(mangaId),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Image.network(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.broken_image),
                      );
                    }
                    return Center(child: CircularProgressIndicator());
                  },
                ),
              ),
            ),
            SizedBox(width: 16),
            // Thông tin manga
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tiêu đề
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  SizedBox(height: 8),
                  // Mô tả
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
                  SizedBox(height: 8),
                  // Tags
                  Wrap(
                    spacing: 4.0,
                    runSpacing: 4.0,
                    children: tags.take(3).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            // Nút xóa (nếu là danh sách theo dõi)
            if (isFollowing)
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red,
                ),
                onPressed: () => handleUnfollow(mangaId),
              ),
          ],
        ),
      ),
    );
  }
}


