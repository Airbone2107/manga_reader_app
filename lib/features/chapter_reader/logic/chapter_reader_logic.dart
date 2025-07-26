// lib/features/chapter_reader/logic/chapter_reader_logic.dart
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../data/models/chapter_model.dart';
import '../../../data/services/mangadex_api_service.dart';
import '../../../data/services/user_api_service.dart';
import '../../../data/storage/secure_storage_service.dart';
import '../view/chapter_reader_screen.dart';

class ChapterReaderLogic {
  final Function(VoidCallback) setState;
  final UserApiService userService;
  final ScrollController scrollController;
  final MangaDexApiService mangaDexService = MangaDexApiService();

  bool areBarsVisible = true;
  double lastOffset = 0.0;
  double scrollThreshold = 50.0;

  ChapterReaderLogic({
    required this.setState,
    required this.userService,
    required this.scrollController,
  }) {
    scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final currentOffset = scrollController.offset;
    final delta = currentOffset - lastOffset;

    if (delta.abs() > scrollThreshold) {
      if (delta > 0 && areBarsVisible) {
        setState(() => areBarsVisible = false);
      } else if (delta < 0 && !areBarsVisible) {
        setState(() => areBarsVisible = true);
      }
      lastOffset = currentOffset;
    }
  }

  int getCurrentIndex(Chapter chapter) {
    return chapter.chapterList
        .indexWhere((ch) => ch['id'] == chapter.chapterId);
  }

  String getChapterDisplayName(Map<String, dynamic> chapter) {
    String chapterNumber = chapter['attributes']['chapter'] ?? 'N/A';
    String chapterTitle = chapter['attributes']['title'] ?? '';
    return chapterTitle.isEmpty || chapterTitle == chapterNumber
        ? 'Chương $chapterNumber'
        : 'Chương $chapterNumber: $chapterTitle';
  }

  Future<List<String>> fetchChapterPages(String chapterId) {
    return mangaDexService.fetchChapterPages(chapterId);
  }

  // Danh sách chương được sắp xếp theo thứ tự giảm dần (chương mới nhất ở đầu).
  // Vì vậy, "chương kế tiếp" (số chương lớn hơn) sẽ có chỉ số (index) nhỏ hơn trong danh sách.
  void goToNextChapter(
      BuildContext context, Chapter chapter, int currentIndex) {
    if (currentIndex > 0) {
      // Có thể đi tới chương có index nhỏ hơn (số chương lớn hơn)
      var nextChapterData = chapter.chapterList[currentIndex - 1];
      _navigateToChapter(context, chapter, nextChapterData);
    }
  }

  // Tương tự, "chương trước" (số chương nhỏ hơn) sẽ có chỉ số (index) lớn hơn.
  void goToPreviousChapter(
      BuildContext context, Chapter chapter, int currentIndex) {
    if (currentIndex < chapter.chapterList.length - 1) {
      // Có thể đi tới chương có index lớn hơn (số chương nhỏ hơn)
      var prevChapterData = chapter.chapterList[currentIndex + 1];
      _navigateToChapter(context, chapter, prevChapterData);
    }
  }

  void _navigateToChapter(BuildContext context, Chapter currentChapter,
      Map<String, dynamic> newChapterData) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterReaderScreen(
          chapter: Chapter(
            mangaId: currentChapter.mangaId,
            chapterId: newChapterData['id'],
            chapterName: getChapterDisplayName(newChapterData),
            chapterList: currentChapter.chapterList,
          ),
        ),
      ),
    );
  }

  Future<void> followManga(BuildContext context, String mangaId) async {
    try {
      final token = await SecureStorageService.getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vui lòng đăng nhập để theo dõi truyện.')),
        );
        return;
      }
      await userService.addToFollowing(mangaId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm truyện vào danh sách theo dõi.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi thêm truyện: $e')),
      );
    }
  }

  Future<void> removeFromFollowing(BuildContext context, String mangaId) async {
    try {
      final token = await SecureStorageService.getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vui lòng đăng nhập để bỏ theo dõi truyện.')),
        );
        return;
      }
      await userService.removeFromFollowing(mangaId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã bỏ theo dõi truyện.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi bỏ theo dõi truyện: $e')),
      );
    }
  }

  Future<bool> isFollowingManga(String mangaId) async {
    try {
      final token = await SecureStorageService.getToken();
      if (token == null) {
        return false;
      }
      return await userService.checkIfUserIsFollowing(mangaId);
    } catch (e) {
      print("Lỗi khi kiểm tra theo dõi: $e");
      return false;
    }
  }

  Future<void> updateProgress(String mangaId, String chapterId) async {
    try {
      final token = await SecureStorageService.getToken();
      if (token != null) {
        await userService.updateReadingProgress(mangaId, chapterId);
      }
    } catch (e) {
      print('Lỗi khi cập nhật tiến độ đọc: $e');
    }
  }

  void dispose() {
    scrollController.removeListener(_onScroll);
  }
}
