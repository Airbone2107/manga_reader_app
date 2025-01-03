// Thư viện Flutter và các gói cần thiết
import 'package:flutter/material.dart'; // Thư viện Flutter chính
import 'package:google_sign_in/google_sign_in.dart'; // Thư viện đăng nhập Google
import 'package:intl/intl.dart'; // Thư viện định dạng ngày tháng

// Các class xử lý liên quan đến lưu trữ và dịch vụ người dùng
import '../../local_storage/secure_user_manager.dart'; // Quản lý dữ liệu người dùng an toàn
import '../../services/manga_user_service.dart'; // Dịch vụ xử lý người dùng
import '../../services/model.dart'; // Mô hình dữ liệu cho ứng dụng

/// Logic xử lý cho màn hình tài khoản người dùng.
class AccountScreenLogic {
  // Đối tượng quản lý đăng nhập Google
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

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
  void init(BuildContext context, VoidCallback refreshUI) {
    this.context = context;
    this.refreshUI = refreshUI;
    _initializeGoogleSignIn(); // Thiết lập Google Sign-In
    _loadStoredUser(); // Tải dữ liệu người dùng đã lưu
  }

  /// Hủy logic và giải phóng tài nguyên.
  void dispose() {
    _userService.dispose(); // Đóng kết nối dịch vụ
  }

  /// Tải dữ liệu người dùng đã lưu từ bộ nhớ cục bộ.
  Future<void> _loadStoredUser() async {
    try {
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
        await _refreshUserData(); // Làm mới dữ liệu người dùng từ API
        refreshUI(); // Cập nhật giao diện
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
      isLoading = true;
      refreshUI();

      user = await _userService
          .signInWithGoogle(googleUser); // Đăng nhập qua Google
      await StorageService.saveUserInfo(
        id: user!.id,
        googleId: user!.googleId,
        email: user!.email,
        displayName: user!.displayName,
        photoURL: user!.photoURL,
        createdAt: user!.createdAt,
      );

      isLoading = false;
      refreshUI();
    } catch (e) {
      isLoading = false;
      refreshUI();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lấy thông tin: $e')),
      );
    }
  }

  /// Xử lý đăng nhập Google khi người dùng nhấn nút đăng nhập.
  Future<void> handleSignIn() async {
    try {
      isLoading = true;
      refreshUI();
      await _googleSignIn.signIn();
      isLoading = false;
      refreshUI();
    } catch (error) {
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
      await _googleSignIn.disconnect();
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
        onPressed: () => handleUnfollow(mangaId), // Bỏ theo dõi truyện
      ),
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
    );
  }

  /// Xử lý bỏ theo dõi một truyện.
  Future<void> handleUnfollow(String mangaId) async {
    try {
      await _userService.removeFromFollowing(user!.id, mangaId);
      if (currentUser != null) {
        await _fetchUserData(
            currentUser!); // Cập nhật dữ liệu sau khi bỏ theo dõi
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã bỏ theo dõi truyện')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi bỏ theo dõi: $e')),
      );
    }
  }
}
