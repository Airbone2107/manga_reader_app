import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import '../local_storage/secure_user_manager.dart';
import '../services/manga_user_service.dart';
import '../services/model.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final UserService _userService = UserService(
    baseUrl: 'https://manga-reader-app-backend.onrender.com',
  );

  GoogleSignInAccount? _currentUser;
  User? _user;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStoredUser();
    _initializeGoogleSignIn();
  }
  Future<void> _loadStoredUser() async {
    try {
      final userInfo = await StorageService.getUserInfo();
      if (userInfo['id'] != null) {
        setState(() {
          _user = User(
            id: userInfo['id']!,
            googleId: userInfo['googleId']!,
            email: userInfo['email']!,
            displayName: userInfo['displayName']!,
            photoURL: userInfo['photoURL'],
            following: [],
            readingProgress: [],
            createdAt: DateTime.parse(userInfo['createdAt'] ?? DateTime.now().toIso8601String()),
          );
        });
        await _refreshUserData();
      }
    } catch (e) {
      print('Lỗi khi đọc dữ liệu đã lưu: $e');
    }
  }
  Future<void> _refreshUserData() async {
    if (_user != null) {
      try {
        final updatedUser = await _userService.getUserData(_user!.id);
        setState(() {
          _user = updatedUser;
        });
      } catch (e) {
        print('Lỗi khi refresh dữ liệu: $e');
      }
    }
  }
  @override
  void dispose() {
    _userService.dispose();
    super.dispose();
  }

  Future<void> _initializeGoogleSignIn() async {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
      setState(() {
        _currentUser = account;
      });

      if (_currentUser != null) {
        await _fetchUserData(_currentUser!);
      }
    });

    try {
      await _googleSignIn.signInSilently();
    } catch (e) {
      print('Lỗi đăng nhập tự động: $e');
    }
  }

  Future<void> _fetchUserData(GoogleSignInAccount googleUser) async {
    try {
      setState(() {
        _isLoading = true;
      });
      _user = await _userService.signInWithGoogle(googleUser);

      // Lưu thông tin cơ bản
      await StorageService.saveUserInfo(
        id: _user!.id,
        googleId: _user!.googleId,
        email: _user!.email,
        displayName: _user!.displayName,
        photoURL: _user!.photoURL,
        createdAt: _user!.createdAt, // Thêm createdAt
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lấy thông tin: $e')),
        );
      }
    }
  }

  Future<void> _handleSignIn() async {
    try {
      setState(() {
        _isLoading = true;
      });
      await _googleSignIn.signIn();
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi đăng nhập: $error')),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await _googleSignIn.disconnect();
      await StorageService.clearAll(); // Xóa dữ liệu đã lưu
      setState(() {
        _currentUser = null;
        _user = null;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi đăng xuất: $error')),
        );
      }
    }
  }

  Future<void> _handleUnfollow(String mangaId) async {
    try {
      await _userService.removeFromFollowing(_user!.id, mangaId);
      if (_currentUser != null) {
        await _fetchUserData(_currentUser!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã bỏ theo dõi truyện')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi bỏ theo dõi: $e')),
        );
      }
    }
  }

  Widget _buildMangaList<T>(String title, List<T> items, Widget Function(T) itemBuilder) {
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

  Widget _buildFollowingItem(String mangaId) {
    return ListTile(
      title: Text(mangaId),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: () => _handleUnfollow(mangaId),
      ),
    );
  }

  Widget _buildReadingItem(ReadingProgress progress) {
    return ListTile(
      title: Text(progress.mangaId),
      subtitle: Text('Chapter ${progress.lastChapter}'),
      trailing: Text(
        DateFormat('dd/MM/yyyy').format(progress.lastReadAt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản của bạn'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentUser == null) {
      return Center(
        child: ElevatedButton(
          onPressed: _handleSignIn,
          child: const Text("Đăng nhập với Google"),
        ),
      );
    }

    if (_user == null) {
      return const Center(child: Text('Đang tải thông tin...'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (_currentUser != null) {
          await _fetchUserData(_currentUser!);
        }
      },
      child: _buildUserContent(),
    );
  }

  Widget _buildUserContent() {
    return Column(
      children: [
        UserAccountsDrawerHeader(
          accountName: Text(_user!.displayName),
          accountEmail: Text(_user!.email),
          currentAccountPicture: _user!.photoURL != null && _user!.photoURL!.isNotEmpty
              ? CircleAvatar(
            backgroundImage: NetworkImage(_user!.photoURL!),
          )
              : CircleAvatar(
            backgroundColor: Colors.blue,
            child: Text(
              _user!.displayName.isNotEmpty
                  ? _user!.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8.0),
            children: [
              _buildMangaList<String>(
                  'Truyện Theo Dõi',
                  _user!.following,
                  _buildFollowingItem
              ),
              const SizedBox(height: 16),
              _buildMangaList<ReadingProgress>(
                  'Lịch Sử Đọc Truyện',
                  _user!.readingProgress,
                  _buildReadingItem
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _handleSignOut,
                  child: const Text("Đăng xuất"),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}