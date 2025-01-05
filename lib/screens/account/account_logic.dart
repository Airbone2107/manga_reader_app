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
      print('Google ID Token: ${auth.idToken}');

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

      final auth = await account.authentication.then((value) {
        print('Authentication success');
        print('Access Token: ${value.accessToken}');
        print('ID Token: ${value.idToken}');
        return value;
      }).catchError((error) {
        print('Authentication error: $error');
        throw error;
      });

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
}
