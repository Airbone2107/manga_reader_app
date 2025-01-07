// Thư viện Flutter và các gói cần thiết
import 'package:flutter/material.dart'; // Thư viện Flutter chính
import 'package:google_sign_in/google_sign_in.dart'; // Thư viện đăng nhập Google
import 'package:intl/intl.dart'; // Thư viện định dạng ngày tháng

// Các class xử lý liên quan đến lưu trữ và dịch vụ người dùng
import '../../local_storage/secure_user_manager.dart'; // Quản lý dữ liệu người dùng an toàn
import '../../services/manga_dex_service.dart';
import '../../services/manga_user_service.dart'; // Dịch vụ xử lý người dùng
import '../../services/model.dart';
import '../detail_manga/manga_detail_screen.dart'; // Mô hình dữ liệu cho ứng dụng

/// Logic xử lý cho màn hình tài khoản người dùng.
class AccountScreenLogic {
  final MangaDexService _mangaDexService = MangaDexService();
  final Map<String, dynamic> _mangaCache = {};

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    signInOption: SignInOption.standard, // Thêm option này
  );

  // Dịch vụ người dùng để giao tiếp với API
  final UserService _userService = UserService(
    baseUrl: 'https://manga-reader-app-backend.onrender.com',
  );

  // Các biến lưu trạng thái
  GoogleSignInAccount? currentUser; // Người dùng hiện tại đăng nhập qua Google
  User? user; // Người dùng trong ứng dụng
  bool isLoading = false; // Trạng thái tải dữ liệu
  late BuildContext context; // Ngữ cảnh xây dựng giao diện
  late VoidCallback refreshUI; // Hàm callback để cập nhật giao diện

  /// Khởi tạo logic màn hình với ngữ cảnh và hàm callback cập nhật giao diện.
  Future<void> init(BuildContext context, VoidCallback refreshUI) async {
    this.context = context;
    this.refreshUI = refreshUI;
    await _userService.initToken(); // Khởi tạo token
    _initializeGoogleSignIn();
    await _loadStoredUser();
  }

  /// Hủy logic và giải phóng tài nguyên.
  void dispose() {
    _userService.dispose(); // Đóng kết nối dịch vụ
  }

  /// Tải dữ liệu người dùng đã lưu từ bộ nhớ cục bộ.
  Future<void> _loadStoredUser() async {
    try {
      // Kiểm tra token và đăng nhập
      final isLoggedIn = await _userService.isLoggedIn();
      if (isLoggedIn) {
        final userInfo = await StorageService.getUserInfo();
        if (userInfo['id'] != null) {
          user = User(
            id: userInfo['id']!,
            googleId: userInfo['googleId']!,
            email: userInfo['email']!,
            displayName: userInfo['displayName']!,
            photoURL: userInfo['photoURL'],
            following: [],
            readingProgress: [],
            createdAt: DateTime.parse(
                userInfo['createdAt'] ?? DateTime.now().toIso8601String()),
          );
          await _refreshUserData();
          refreshUI();
        }
      }
    } catch (e) {
      print('Lỗi khi đọc dữ liệu đã lưu: $e');
    }
  }

  /// Làm mới dữ liệu người dùng từ API.
  Future<void> _refreshUserData() async {
    if (user != null) {
      try {
        final updatedUser = await _userService.getUserData(user!.id);
        user = updatedUser; // Cập nhật dữ liệu người dùng
        refreshUI(); // Cập nhật giao diện
      } catch (e) {
        print('Lỗi khi refresh dữ liệu: $e');
      }
    }
  }

  /// Thiết lập đăng nhập Google và xử lý sự kiện thay đổi người dùng.
  Future<void> _initializeGoogleSignIn() async {
    _googleSignIn.onCurrentUserChanged
        .listen((GoogleSignInAccount? account) async {
      currentUser = account; // Cập nhật người dùng hiện tại
      refreshUI(); // Cập nhật giao diện

      if (currentUser != null) {
        await _fetchUserData(currentUser!); // Lấy dữ liệu người dùng
      }
    });

    try {
      await _googleSignIn.signInSilently(); // Đăng nhập tự động nếu có thể
    } catch (e) {
      print('Lỗi đăng nhập tự động: $e');
    }
  }

  /// Lấy thông tin người dùng từ Google và cập nhật trong ứng dụng.
  Future<void> _fetchUserData(GoogleSignInAccount googleUser) async {
    try {
      // Lấy authentication từ Google
      final auth = await googleUser.authentication;
      print('Google Auth Token: ${auth.accessToken}');

      // Gọi API đăng nhập
      user = await _userService.signInWithGoogle(googleUser);
      currentUser = googleUser;

      print('User logged in successfully: ${user?.email}');
    } catch (e) {
      print('Fetch user data error: $e');
      throw Exception('Lỗi khi lấy thông tin: $e');
    }
  }

  /// Xử lý đăng nhập Google khi người dùng nhấn nút đăng nhập.
  Future<void> handleSignIn() async {
    try {
      isLoading = true;
      refreshUI();

      // Đảm bảo đăng xuất trước
      await _googleSignIn.signOut();

      // Thử đăng nhập với yêu cầu ID token
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw Exception('Đăng nhập bị hủy');
      }

      await _fetchUserData(account);

      isLoading = false;
      refreshUI();
    } catch (error) {
      print('Sign In Error Details: $error');
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
      await _userService.logout(); // Gọi API đăng xuất trước
      await _googleSignIn.signOut(); // Sau đó đăng xuất Google
      await StorageService.clearAll();
      currentUser = null;
      user = null;
      refreshUI();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đăng xuất: $error')),
      );
    }
  }

  /// Làm mới dữ liệu người dùng nếu đang đăng nhập.
  Future<void> refreshUserData() async {
    if (currentUser != null) {
      await _fetchUserData(currentUser!);
    }
  }

  /// Tạo danh sách mở rộng hiển thị dữ liệu theo tiêu đề và danh sách.
  Widget buildMangaList<T>(String title, List<T> items, Widget Function(T) itemBuilder) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ExpansionTile(
        title: Text(title),
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Không có dữ liệu'),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) => itemBuilder(items[index]),
            ),
        ],
      ),
    );
  }

  /// Hiển thị một mục trong danh sách truyện đang theo dõi.
  Widget buildFollowingItem(String mangaId) {
    return ListTile(
      title: Text(mangaId),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: () => handleUnfollow(mangaId),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MangaDetailScreen(mangaId: mangaId),
          ),
        );
      },
    );
  }

  /// Hiển thị một mục trong danh sách tiến trình đọc truyện.
  Widget buildReadingItem(ReadingProgress progress) {
    return ListTile(
      title: Text(progress.mangaId),
      subtitle: Text('Chapter ${progress.lastChapter}'),
      trailing: Text(
        DateFormat('dd/MM/yyyy').format(progress.lastReadAt),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MangaDetailScreen(mangaId: progress.mangaId),
          ),
        );
      },
    );
  }

  /// Xử lý bỏ theo dõi một truyện.
  Future<void> handleUnfollow(String mangaId) async {
    try {
      if (user == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }

      isLoading = true;
      refreshUI();

      await _userService.removeFromFollowing(user!.id, mangaId);

      // Cập nhật lại dữ liệu người dùng
      final updatedUser = await _userService.getUserData(user!.id);
      user = updatedUser;

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

  /// Lấy thông tin cho danh sách manga
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

  /// Xây dựng widget hiển thị danh sách manga
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
  /// Xây dựng widget cho một mục manga trong danh sách
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
  }}
