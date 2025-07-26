
---

### **1. Hardcode URL và các giá trị cấu hình**

*   **Vấn đề:** URL của backend (`https://manga-reader-app-backend.onrender.com`) bị lặp lại ở nhiều nơi (`UserApiService`, `AccountScreenLogic`, `MangaDetailLogic`, `ChapterReaderScreen`).
*   **Tại sao cần thay đổi:** Khi bạn cần thay đổi URL (ví dụ: chuyển sang server khác hoặc có môi trường test), bạn sẽ phải sửa ở rất nhiều file, dễ gây ra lỗi và tốn thời gian.
*   **Giải pháp:** Tạo một file cấu hình tập trung (`app_config.dart`) để quản lý tất cả các hằng số và giá trị cấu hình. Sau đó, các service sẽ sử dụng giá trị từ file này.

#### **Các file cần thay đổi:**

**Bước 1: Tạo file cấu hình mới**

File này sẽ là nơi duy nhất chứa URL của backend.

```dart
// lib/config/app_config.dart
class AppConfig {
  static const String baseUrl = 'https://manga-reader-app-backend.onrender.com';
}
```

**Bước 2: Cập nhật `UserApiService` để sử dụng cấu hình**

Service này sẽ tự động lấy URL từ file config, giúp các nơi khác không cần quan tâm đến URL nữa.

```dart
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
```

**Bước 3: Cập nhật các file Logic để bỏ việc truyền `baseUrl`**

```dart
// lib/features/account/logic/account_logic.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../data/models/chapter_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/mangadex_api_service.dart';
import '../../../data/services/user_api_service.dart';
import '../../../data/storage/secure_storage_service.dart';
import '../../chapter_reader/view/chapter_reader_screen.dart';
import '../../detail_manga/view/manga_detail_screen.dart';

class AccountScreenLogic {
  final MangaDexApiService _mangaDexService = MangaDexApiService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final UserApiService _userService = UserApiService(); // Không cần truyền baseUrl
  final Map<String, dynamic> _mangaCache = {};

  User? user;
  bool isLoading = false;
  late BuildContext context;
  late VoidCallback refreshUI;

  Future<void> init(BuildContext context, VoidCallback refreshUI) async {
    this.context = context;
    this.refreshUI = refreshUI;
    await _loadUser();
  }

  Future<void> _loadUser() async {
    isLoading = true;
    refreshUI();
    try {
      final hasToken = await SecureStorageService.hasValidToken();
      if (hasToken) {
        user = await _fetchUserData();
      } else {
        user = null;
      }
    } catch (e) {
      user = null;
      if (e is HttpException && e.message == '403') {
        await handleSignOut(); // Token is invalid, force sign out
      }
      print("Lỗi khi tải người dùng: $e");
    } finally {
      isLoading = false;
      refreshUI();
    }
  }

  Future<void> handleSignIn() async {
    isLoading = true;
    refreshUI();
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw Exception('Đăng nhập bị hủy');
      }
      await _userService.signInWithGoogle(account);
      user = await _fetchUserData();
    } catch (error) {
      print('Lỗi đăng nhập: $error');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi đăng nhập: $error')));
      user = null;
    } finally {
      isLoading = false;
      refreshUI();
    }
  }

  Future<void> handleSignOut() async {
    try {
      await _googleSignIn.signOut();
      await SecureStorageService.removeToken();
      user = null;
      refreshUI();
    } catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi đăng xuất: $error')));
    }
  }

  Future<void> refreshUserData() async {
    await _loadUser();
  }

  Future<User> _fetchUserData() async {
    return await _userService.getUserData();
  }

  Future<void> handleUnfollow(String mangaId) async {
    try {
      if (user == null) throw Exception('Người dùng chưa đăng nhập');
      isLoading = true;
      refreshUI();
      await _userService.removeFromFollowing(mangaId);
      user = await _fetchUserData();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã bỏ theo dõi truyện')));
    } catch (e) {
      print('Error in handleUnfollow: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi khi bỏ theo dõi: $e')));
    } finally {
      isLoading = false;
      refreshUI();
    }
  }

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

  Widget buildMangaListView(String title, List<String> mangaIds,
      {bool isFollowing = false}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getMangaListInfo(mangaIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
              child: ListTile(
                  title: Text(title),
                  subtitle: Center(child: CircularProgressIndicator())));
        }
        if (snapshot.hasError) {
          return Card(
              child: ListTile(
                  title: Text(title),
                  subtitle: Text('Lỗi: ${snapshot.error}')));
        }
        final mangas = snapshot.data ?? [];
        for (var manga in mangas) _mangaCache[manga['id']] = manga;
        return Card(
          margin: EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: mangaIds.length,
                itemBuilder: (context, index) {
                  final mangaId = mangaIds[index];
                  final manga = _mangaCache[mangaId];
                  if (manga == null) return SizedBox.shrink();
                  String? lastReadChapter;
                  if (!isFollowing && user != null) {
                    final progress = user!.readingProgress.firstWhere(
                        (p) => p.mangaId == mangaId,
                        orElse: () => ReadingProgress(
                            mangaId: mangaId,
                            lastChapter: '',
                            lastReadAt: DateTime.now()));
                    lastReadChapter = progress.lastChapter;
                  }
                  return _buildMangaListItem(manga,
                      isFollowing: isFollowing,
                      mangaId: mangaId,
                      lastReadChapter: lastReadChapter);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMangaListItem(Map<String, dynamic> manga,
      {bool isFollowing = false,
      required String mangaId,
      String? lastReadChapter}) {
    final title = manga['attributes']?['title']?['en'] ?? 'Không có tiêu đề';
    return Container(
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 6.0,
              offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => MangaDetailScreen(mangaId: mangaId))),
            child: Container(
              width: 80,
              height: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
                child: FutureBuilder<String>(
                  future: _mangaDexService.fetchCoverUrl(mangaId),
                  builder: (context, snapshot) {
                    if (snapshot.hasData)
                      return Image.network(snapshot.data!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.broken_image));
                    return Center(child: CircularProgressIndicator());
                  },
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
                SizedBox(height: 8),
                FutureBuilder<List<dynamic>>(
                  future: _mangaDexService.fetchChapters(mangaId, 'en,vi'),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return SizedBox(
                          height: 50,
                          child: Center(child: CircularProgressIndicator()));
                    if (snapshot.hasError) return Text('Không thể tải chapter');
                    var chapter = snapshot.data!.first;
                    String chapterNumber =
                        chapter['attributes']['chapter'] ?? 'N/A';
                    String chapterTitle = chapter['attributes']['title'] ?? '';
                    String displayTitle = chapterTitle.isEmpty
                        ? 'Chương $chapterNumber'
                        : 'Chương $chapterNumber: $chapterTitle';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(displayTitle,
                          style: TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ChapterReaderScreen(
                                  chapter: Chapter(
                                      mangaId: mangaId,
                                      chapterId: chapter['id'],
                                      chapterName: displayTitle,
                                      chapterList: snapshot.data!)))),
                    );
                  },
                ),
              ],
            ),
          ),
          if (isFollowing)
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => handleUnfollow(mangaId),
            ),
        ],
      ),
    );
  }

  void dispose() {}
}
```

```dart
// lib/features/detail_manga/logic/manga_detail_logic.dart
import 'package:flutter/material.dart';
import '../../../data/services/mangadex_api_service.dart';
import '../../../data/services/user_api_service.dart';
import '../../../data/storage/secure_storage_service.dart';

class MangaDetailLogic {
  final String mangaId;
  final VoidCallback refreshUI;

  final MangaDexApiService _mangaDexService = MangaDexApiService();
  final UserApiService _userApiService = UserApiService(); // Không cần truyền baseUrl

  late Future<Map<String, dynamic>> mangaDetails;
  late Future<List<dynamic>> chapters;
  late Future<String> coverUrl;
  bool isFollowing = false;

  MangaDetailLogic({required this.mangaId, required this.refreshUI}) {
    _init();
  }

  void _init() {
    List<String> defaultLanguages = ['en', 'vi'];
    mangaDetails = _mangaDexService.fetchMangaDetails(mangaId);
    chapters = _mangaDexService.fetchChapters(
      mangaId,
      defaultLanguages.join(','),
    );
    coverUrl = _mangaDexService.fetchCoverUrl(mangaId);
    checkFollowingStatus();
  }

  Future<void> checkFollowingStatus() async {
    try {
      final token = await SecureStorageService.getToken();
      if (token == null) {
        isFollowing = false;
        refreshUI();
        return;
      }
      bool following = await _userApiService.checkIfUserIsFollowing(mangaId);
      isFollowing = following;
      refreshUI();
    } catch (e) {
      print("Lỗi khi kiểm tra theo dõi: $e");
      isFollowing = false;
      refreshUI();
    }
  }

  Future<void> toggleFollowStatus(BuildContext context) async {
    final token = await SecureStorageService.getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng đăng nhập để theo dõi truyện.')),
      );
      return;
    }

    try {
      if (isFollowing) {
        await _userApiService.removeFromFollowing(mangaId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã bỏ theo dõi truyện.')),
        );
      } else {
        await _userApiService.addToFollowing(mangaId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm truyện vào danh sách theo dõi.')),
        );
      }
      await checkFollowingStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }
}
```

---

### **2. Cải thiện Logic và Giao diện**

#### **2.1. Trùng lặp code giao diện và logic cuộn trang**

*   **Vấn đề:** Hai file `home_screen.dart` và `manga_list_search.dart` có logic giống hệt nhau để ẩn/hiện `AppBar` và nút "lên đầu trang" khi cuộn.
*   **Tại sao cần thay đổi:** Trùng lặp code làm tăng khối lượng công việc khi cần sửa chữa hoặc nâng cấp. Nếu bạn muốn thay đổi hiệu ứng cuộn, bạn sẽ phải sửa ở cả hai nơi.
*   **Giải pháp:** Tạo một widget có thể tái sử dụng (`ScaffoldWithAnimatedAppBar`) để bao bọc logic này. Widget này sẽ quản lý `AppBar`, nút cuộn và `ScrollController`, giúp hai màn hình trên trở nên đơn giản và chỉ cần tập trung vào việc hiển thị nội dung.

#### **Các file cần thay đổi:**

**Bước 1: Tạo một Shared Widget mới**

Widget này sẽ chứa toàn bộ logic về `AppBar` động và nút "lên đầu trang".

```dart
// lib/shared_widgets/scaffold_with_animated_app_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ScaffoldWithAnimatedAppBar extends StatefulWidget {
  final String title;
  final Widget Function(ScrollController controller) bodyBuilder;
  final List<Widget>? actions;

  const ScaffoldWithAnimatedAppBar({
    Key? key,
    required this.title,
    required this.bodyBuilder,
    this.actions,
  }) : super(key: key);

  @override
  _ScaffoldWithAnimatedAppBarState createState() =>
      _ScaffoldWithAnimatedAppBarState();
}

class _ScaffoldWithAnimatedAppBarState
    extends State<ScaffoldWithAnimatedAppBar> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTopButton = false;
  bool _isAppBarVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!mounted) return;

    if (_scrollController.offset >= 400 && !_showScrollToTopButton) {
      setState(() => _showScrollToTopButton = true);
    } else if (_scrollController.offset < 400 && _showScrollToTopButton) {
      setState(() => _showScrollToTopButton = false);
    }

    final scrollDirection = _scrollController.position.userScrollDirection;
    if (scrollDirection == ScrollDirection.reverse && _isAppBarVisible) {
      setState(() => _isAppBarVisible = false);
    } else if (scrollDirection == ScrollDirection.forward &&
        !_isAppBarVisible) {
      setState(() => _isAppBarVisible = true);
    }
  }

  void _scrollToTop() {
    setState(() => _isAppBarVisible = true);
    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double appBarHeight = kToolbarHeight;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedPadding(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.only(
                top: _isAppBarVisible
                    ? appBarHeight + statusBarHeight
                    : statusBarHeight),
            child: widget.bodyBuilder(_scrollController),
          ),
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: _isAppBarVisible ? 0 : -(appBarHeight + statusBarHeight),
            left: 0,
            right: 0,
            child: Container(
              color: Theme.of(context).appBarTheme.backgroundColor ??
                  Theme.of(context).primaryColor,
              child: AppBar(
                title: Text(widget.title),
                elevation: 0,
                actions: widget.actions,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _showScrollToTopButton
          ? FloatingActionButton(
              mini: true,
              onPressed: _scrollToTop,
              child: Icon(Icons.arrow_upward),
            )
          : null,
    );
  }
}
```

**Bước 2: Cập nhật `HomeScreen` để sử dụng Widget mới**

Giao diện `HomeScreen` giờ đây sẽ gọn hơn rất nhiều.

```dart
// lib/features/home/view/home_screen.dart
import 'package:flutter/material.dart';
import '../../../data/models/sort_manga_model.dart';
import '../../../shared_widgets/manga_grid_view.dart';
import '../../../shared_widgets/scaffold_with_animated_app_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    return ScaffoldWithAnimatedAppBar(
      title: 'Manga Reader',
      actions: [
        IconButton(
          icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
          },
        ),
      ],
      bodyBuilder: (controller) => MangaGridView(
        sortManga: SortManga(
          languages: ['en', 'vi'],
        ),
        controller: controller,
        isGridView: _isGridView,
      ),
    );
  }
}
```

**Bước 3: Cập nhật `MangaListSearch` để sử dụng Widget mới**

Tương tự, `MangaListSearch` cũng được đơn giản hóa.

```dart
// lib/features/search/view/manga_list_search.dart
import '../../../data/models/sort_manga_model.dart';
import 'package:flutter/material.dart';
import '../../../shared_widgets/manga_grid_view.dart';
import '../../../shared_widgets/scaffold_with_animated_app_bar.dart';

class MangaListSearch extends StatefulWidget {
  final SortManga sortManga;

  const MangaListSearch({
    Key? key,
    required this.sortManga,
  }) : super(key: key);

  @override
  State<MangaListSearch> createState() => _MangaListSearchState();
}

class _MangaListSearchState extends State<MangaListSearch> {
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    return ScaffoldWithAnimatedAppBar(
      title: 'Kết Quả Tìm Kiếm',
      actions: [
        IconButton(
          icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
          },
        ),
      ],
      bodyBuilder: (controller) => MangaGridView(
        sortManga: widget.sortManga,
        controller: controller,
        isGridView: _isGridView,
      ),
    );
  }
}
```

#### **2.2. Cải thiện việc phân tích cú pháp JSON trong Model**

*   **Vấn đề:** Trong `user_model.dart`, `factory User.fromJson` có một khối `try-catch` lớn. Điều này không hiệu quả và có thể che giấu lỗi cụ thể ở từng trường dữ liệu.
*   **Giải pháp:** Sử dụng toán tử `?.` (null-aware), `as?` và cung cấp giá trị mặc định trực tiếp để làm cho code an toàn hơn khi xử lý JSON và dễ đọc hơn.

```dart
// lib/data/models/user_model.dart
class User {
  final String id;
  final String googleId;
  final String email;
  final String displayName;
  final String? photoURL;
  final List<String> following;
  final List<ReadingProgress> readingProgress;
  final DateTime createdAt;

  User({
    required this.id,
    required this.googleId,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.following,
    required this.readingProgress,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] as String? ?? '',
      googleId: json['googleId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      photoURL: json['photoURL'] as String?,
      following: List<String>.from(json['followingManga'] as List? ?? []),
      readingProgress: (json['readingManga'] as List? ?? [])
          .map((x) => ReadingProgress.fromJson(x as Map<String, dynamic>))
          .toList(),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ReadingProgress {
  final String mangaId;
  final String lastChapter;
  final DateTime lastReadAt;

  ReadingProgress({
    required this.mangaId,
    required this.lastChapter,
    required this.lastReadAt,
  });

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      mangaId: json['mangaId'] as String? ?? '',
      lastChapter: json['lastChapter'] as String? ?? '',
      lastReadAt:
          DateTime.tryParse(json['lastReadAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
```

#### **2.3. Đơn giản hóa Widget Cache ảnh**

*   **Vấn đề:** Bạn có một widget `CachedImageWidget` riêng trong khi đã dùng thư viện `cached_network_image`. Thư viện này đã cung cấp đầy đủ chức năng và mạnh mẽ hơn.
*   **Giải pháp:** Xóa file `lib/shared_widgets/cached_image_widget.dart` và sử dụng `CachedNetworkImage` trực tiếp. Điều này giúp giảm code thừa và tận dụng tối đa sức mạnh của thư viện.

**Bước 1: Xóa file `lib/shared_widgets/cached_image_widget.dart`**

**Bước 2: Cập nhật file `chapter_reader_screen.dart`**

```dart
// lib/features/chapter_reader/view/chapter_reader_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../data/models/chapter_model.dart';
import '../../../data/services/user_api_service.dart';
import '../logic/chapter_reader_logic.dart';

class ChapterReaderScreen extends StatefulWidget {
  final Chapter chapter;
  ChapterReaderScreen({required this.chapter});

  @override
  _ChapterReaderScreenState createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  late ChapterReaderLogic _logic;
  late Future<List<String>> _chapterPages;
  final ScrollController _scrollController = ScrollController();
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _logic = ChapterReaderLogic(
      userService: UserApiService(), // Sử dụng constructor mặc định
      setState: (fn) {
        if (mounted) setState(fn);
      },
      scrollController: _scrollController,
    );

    _logic.updateProgress(widget.chapter.mangaId, widget.chapter.chapterId);
    _chapterPages = _logic.fetchChapterPages(widget.chapter.chapterId);
    _checkFollowingStatus();
  }

  Future<void> _checkFollowingStatus() async {
    final followingStatus =
        await _logic.isFollowingManga(widget.chapter.mangaId);
    if (mounted) {
      setState(() {
        _isFollowing = followingStatus;
      });
    }
  }

  @override
  void dispose() {
    _logic.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () =>
            setState(() => _logic.areBarsVisible = !_logic.areBarsVisible),
        child: Stack(
          children: [
            FutureBuilder<List<String>>(
              future: _chapterPages,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Lỗi:  ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('Không có trang nào.'));
                }
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    // Sử dụng CachedNetworkImage trực tiếp
                    return CachedNetworkImage(
                      imageUrl: snapshot.data![index],
                      fit: BoxFit.fitWidth,
                      placeholder: (context, url) => Container(
                        height: 300,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 300,
                        child: Center(child: Icon(Icons.error)),
                      ),
                    );
                  },
                );
              },
            ),
            if (_logic.areBarsVisible) _buildOverlay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    int currentIndex = _logic.getCurrentIndex(widget.chapter);
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildAppBar(context),
        _buildBottomNavBar(context, currentIndex),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: Colors.black54,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Text(
                widget.chapter.chapterName,
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(width: 48), // To balance the back button
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context, int currentIndex) {
    return Container(
      color: Colors.black54,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => _logic.goToPreviousChapter(
                context, widget.chapter, currentIndex),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.home, color: Colors.white),
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context, '/', (route) => false),
          ),
          IconButton(
            icon: Icon(
              Icons.bookmark,
              color: _isFollowing ? Colors.green : Colors.white,
            ),
            onPressed: () async {
              if (_isFollowing) {
                await _logic.removeFromFollowing(
                    context, widget.chapter.mangaId);
              } else {
                await _logic.followManga(context, widget.chapter.mangaId);
              }
              _checkFollowingStatus();
            },
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward, color: Colors.white),
            onPressed: () =>
                _logic.goToNextChapter(context, widget.chapter, currentIndex),
          ),
        ],
      ),
    );
  }
}
```

---

### **Tổng kết**

Sau khi áp dụng các thay đổi trên, project của bạn sẽ:
*   **Dễ bảo trì hơn:** Dễ dàng thay đổi cấu hình, logic giao diện được tái sử dụng, giảm thiểu code trùng lặp.
*   **Gọn gàng hơn:** Loại bỏ code thừa và cải thiện cấu trúc.
*   **An toàn hơn khi xử lý dữ liệu:** Cách xử lý JSON đã được cải thiện để tránh các lỗi không mong muốn.