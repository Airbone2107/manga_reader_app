import '../../services/model.dart';
import 'chapter_reader_screen.dart';
import 'package:flutter/material.dart';
import '../../services/manga_dex_service.dart';
import '../../services/manga_user_service.dart';
import '../../local_storage/secure_user_manager.dart';

class ChapterReaderLogic {
  final Function setState;
  final UserService userService;
  final ScrollController scrollController;
  bool areBarsVisible;
  double lastOffset;
  double scrollThreshold;

  /// Khởi tạo lớp ChapterReaderLogic với các tham số cần thiết.
  ChapterReaderLogic({
    required this.setState,
    required this.userService,
    required this.scrollController,
    this.lastOffset = 0.0,
    this.scrollThreshold = 0.0,
    this.areBarsVisible = true,
  });

  // Hàm dùng để khởi tạo màn hình đọc truyện
  /// Lấy chỉ mục hiện tại của chương trong danh sách các chương.
  int getCurrentIndex(Chapter chapter) {
    return chapter.chapterList
        .indexWhere((ch) => ch['id'] == chapter.chapterId);
  }
  /// Tạo tên hiển thị cho chương dựa trên thông tin thuộc tính của nó.
  String getChapterDisplayName(Map<String, dynamic> chapter) {
    String chapterNumber = chapter['attributes']['chapter'] ?? 'N/A';
    String chapterTitle = chapter['attributes']['title'] ?? '';
    return chapterTitle.isEmpty || chapterTitle == chapterNumber
        ? 'Chương $chapterNumber'
        : 'Chương $chapterNumber: $chapterTitle';
  }
  /// Lấy danh sách các trang của chương dựa trên ID chương.
  Future<List<String>> fetchChapterPages(String chapterId) async {
    return MangaDexService().fetchChapterPages(chapterId);
  }

  // Hàm dùng để xử lý các chức năng trong màn hình đọc truyện
  // Chuyển chương
  /// Điều hướng đến chương tiếp theo.
  void goToNextChapter(BuildContext context, Chapter chapter, int currentIndex) {
    if (currentIndex > 0) {
      var prevChapter = chapter.chapterList[currentIndex - 1];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChapterReaderScreen(
            chapter: Chapter(
              mangaId: chapter.mangaId,
              chapterId: prevChapter['id'],
              chapterName: getChapterDisplayName(prevChapter),
              chapterList: chapter.chapterList,
            ),
          ),
        ),
      );
    }
  }
  /// Điều hướng đến chương trước đó.
  void goToPreviousChapter(BuildContext context, Chapter chapter, int currentIndex) {
    if (currentIndex < chapter.chapterList.length - 1) {
      var nextChapter = chapter.chapterList[currentIndex + 1];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChapterReaderScreen(
            chapter: Chapter(
              mangaId: chapter.mangaId,
              chapterId: nextChapter['id'],
              chapterName: getChapterDisplayName(nextChapter),
              chapterList: chapter.chapterList,
            ),
          ),
        ),
      );
    }
  }

  // Giao Diện
  /// Bật hoặc tắt hiển thị thanh công cụ dựa trên vị trí cuộn hiện tại.
  void toggleBarsVisibility(double currentOffset) {
    double delta = currentOffset - lastOffset;

    if (delta > scrollThreshold && areBarsVisible) {
      setState(() {
        areBarsVisible = false;
      });
    } else if (delta < -scrollThreshold && !areBarsVisible) {
      setState(() {
        areBarsVisible = true;
      });
    }

    if (delta.abs() > scrollThreshold) {
      lastOffset = currentOffset;
    }
  }

  //Theo dõi
  /// Thêm truyện vào danh sách theo dõi của người dùng.
  Future<void> followManga(BuildContext context, String mangaId) async {
    try {
      final userInfo = await StorageService.getUserInfo();
      final userId = userInfo['id'];

      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vui lòng đăng nhập để theo dõi truyện.')),
        );
        return;
      }

      await userService.addToFollowing(userId, mangaId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm truyện vào danh sách theo dõi.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi thêm truyện: $e')),
      );
    }
  }
}
