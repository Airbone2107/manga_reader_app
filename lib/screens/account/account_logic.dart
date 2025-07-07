// Thư viện Flutter và các gói cần thiết
import 'dart:io';

import 'package:flutter/material.dart'; // Thư viện Flutter chính
import 'package:google_sign_in/google_sign_in.dart'; // Thư viện đăng nhập Google

// Các class xử lý liên quan đến lưu trữ và dịch vụ người dùng
import '../../local_storage/secure_user_manager.dart'; // Quản lý dữ liệu người dùng an toàn
import '../../services/manga_dex_service.dart';
import '../../services/manga_user_service.dart'; // Dịch vụ xử lý người dùng
import '../../services/model.dart';
import '../chapter/chapter_reader_screen.dart';
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
        throw HttpException(
            'Lỗi không xác định khi lấy dữ liệu người dùng: ${e.message}');
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
  Future<List<Map<String, dynamic>>> _getMangaListInfo(
      List<String> mangaIds) async {
    try {
      final List<dynamic> mangas =
          await _mangaDexService.fetchMangaByIds(mangaIds);
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
  Widget buildMangaListView(
    String title,
    List<String> mangaIds, {
    bool isFollowing = false,
    Key? key,
  }) {
    // Tạo một Map để cache dữ liệu manga
    final Map<String, Map<String, dynamic>> _mangaCache = {};

    return FutureBuilder<List<Map<String, dynamic>>>(
      key: key, // Sử dụng key được truyền vào
      future: _getMangaListInfo(mangaIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            child: ListTile(
              title: Text(title),
              subtitle: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              title: Text(title),
              subtitle: Text('Lỗi: ${snapshot.error}'),
            ),
          );
        }

        final mangas = snapshot.data ?? [];

        // Cache manga data
        for (var manga in mangas) {
          _mangaCache[manga['id']] = manga;
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: mangaIds.length,
                itemBuilder: (context, index) {
                  final mangaId = mangaIds[index];
                  final manga = _mangaCache[mangaId];

                  if (manga == null) {
                    return SizedBox
                        .shrink(); // Skip if manga data is not available
                  }

                  // Tìm tiến độ đọc cho manga này
                  String? lastReadChapter;
                  if (!isFollowing && user != null) {
                    final progress = user!.readingProgress.firstWhere(
                      (p) => p.mangaId == mangaId,
                      orElse: () => ReadingProgress(
                        mangaId: mangaId,
                        lastChapter: '',
                        lastReadAt: DateTime.now(),
                      ),
                    );
                    lastReadChapter = progress.lastChapter;
                  }

                  return _buildMangaListItem(
                    manga,
                    isFollowing: isFollowing,
                    mangaId: mangaId,
                    lastReadChapter: lastReadChapter,
                    key: ValueKey('manga-$mangaId'), // Thêm key cho mỗi item
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMangaListItem(
    Map<String, dynamic> manga, {
    bool isFollowing = false,
    required String mangaId,
    String? lastReadChapter,
    Key? key,
  }) {
    // Lấy tiêu đề từ các ngôn ngữ khác nhau theo thứ tự ưu tiên
    final title = manga['attributes']?['title']?['en'] ??
        manga['attributes']?['title']?['vi'] ??
        manga['attributes']?['title']?.values.firstWhere(
            (title) => title != null && title.isNotEmpty,
            orElse: () => 'Không có tiêu đề');

    return Container(
      key: key,
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
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh bìa manga có thể click
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MangaDetailScreen(mangaId: mangaId),
                ),
              ),
              child: Container(
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
            ),
            SizedBox(width: 16),
            // Thông tin manga và chapters
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  // Danh sách chapter
                  FutureBuilder<List<dynamic>>(
                    future: _mangaDexService.fetchChapters(mangaId, 'en,vi'),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SizedBox(
                          height: 50,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Text('Không thể tải chapter');
                      }

                      List<dynamic> chapters = snapshot.data!;
                      Map<String, List<dynamic>> chaptersByLanguage = {};

                      // Nếu có lastReadChapter, tìm chapter tương ứng
                      if (lastReadChapter != null &&
                          lastReadChapter.isNotEmpty) {
                        var lastReadChapterData = chapters.firstWhere(
                          (chapter) => chapter['id'] == lastReadChapter,
                          orElse: () => null,
                        );

                        if (lastReadChapterData != null) {
                          String lang = lastReadChapterData['attributes']
                              ['translatedLanguage'];
                          chaptersByLanguage[lang] = [lastReadChapterData];
                        }
                      } else {
                        // Nếu không có lastReadChapter hoặc đang ở chế độ following,
                        // hiển thị chapter mới nhất như cũ
                        for (var chapter in snapshot.data!.take(3)) {
                          String lang =
                              chapter['attributes']['translatedLanguage'];
                          if (!chaptersByLanguage.containsKey(lang)) {
                            chaptersByLanguage[lang] = [];
                          }
                          chaptersByLanguage[lang]!.add(chapter);
                        }
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: chaptersByLanguage.entries.map((entry) {
                          String language = entry.key;
                          var chapters = entry.value;
                          var latestChapter = chapters.first;

                          String chapterNumber =
                              latestChapter['attributes']['chapter'] ?? 'N/A';
                          String chapterTitle =
                              latestChapter['attributes']['title'] ?? '';
                          String displayTitle = chapterTitle.isEmpty ||
                                  chapterTitle == chapterNumber
                              ? 'Chương $chapterNumber'
                              : 'Chương $chapterNumber: $chapterTitle';

                          return Container(
                            height: 40, // Cố định chiều cao cho mỗi chapter
                            child: ListTile(
                              dense: true, // Thêm dòng này để giảm padding
                              visualDensity: VisualDensity(
                                  vertical:
                                      -4), // Thêm dòng này để giảm chiều cao
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 30, // Cố định chiều rộng cho language
                                child: Text(
                                  language.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize: 12, // Giảm kích thước chữ
                                  ),
                                ),
                              ),
                              title: Text(
                                displayTitle,
                                style: TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () async {
                                try {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (BuildContext context) {
                                      return Center(
                                          child: CircularProgressIndicator());
                                    },
                                  );

                                  final fullChapterList =
                                      await _mangaDexService.fetchChapters(
                                    mangaId,
                                    language,
                                  );

                                  Navigator.of(context).pop();

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChapterReaderScreen(
                                        chapter: Chapter(
                                          mangaId: mangaId,
                                          chapterId: latestChapter['id'],
                                          chapterName: displayTitle,
                                          chapterList: fullChapterList,
                                        ),
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Lỗi khi tải danh sách chapter: $e')),
                                  );
                                }
                              },
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Nút bỏ theo dõi
            if (isFollowing)
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red,
                ),
                padding: EdgeInsets.zero, // Giảm padding của nút
                constraints: BoxConstraints(), // Bỏ constraints mặc định
                onPressed: () => handleUnfollow(mangaId),
              ),
          ],
        ),
      ),
    );
  }
}
