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
  final UserApiService _userService =
      UserApiService(); // Không cần truyền baseUrl
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
