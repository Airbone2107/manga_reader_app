import '../../services/model.dart'; // Import model dữ liệu (ví dụ: thông tin Chapter, Manga).
import 'chapter_reader_logic.dart'; // Import logic xử lý riêng cho trình đọc chương.
import 'package:flutter/material.dart'; // Import thư viện Flutter để xây dựng giao diện.
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // Import Flutter Cache Manager để quản lý bộ nhớ đệm.

import '../../services/manga_user_service.dart'; // Import dịch vụ người dùng.
import '../../services/image_loader.dart'; // Import lớp hỗ trợ tải và quản lý hình ảnh.

/// Widget hiển thị màn hình đọc chương truyện.
class ChapterReaderScreen extends StatefulWidget {
  final Chapter chapter; // Dữ liệu về chương hiện tại.
  ChapterReaderScreen({required this.chapter});

  @override
  _ChapterReaderScreenState createState() => _ChapterReaderScreenState();
}

/// State quản lý logic và giao diện cho ChapterReaderScreen.
class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  final CacheManager cacheManager = DefaultCacheManager();
  late Future<List<String>> chapterPages;
  List<String?> displayedPages = [];
  late ImageLoader imageLoader;
  final ScrollController _scrollController = ScrollController();
  late ChapterReaderLogic logic;
  bool isFollowing = false; // Biến để lưu trạng thái theo dõi

  @override
  void initState() {
    super.initState();
    logic = ChapterReaderLogic(
      userService: UserService(baseUrl: 'https://manga-reader-app-backend.onrender.com'),
      setState: setState,
      scrollController: _scrollController,
    );

    chapterPages = logic.fetchChapterPages(widget.chapter.chapterId);
    chapterPages.then((pages) {
      setState(() {
        displayedPages = List.filled(pages.length, null);
      });

      imageLoader = ImageLoader(cacheManager: cacheManager);
      imageLoader.loadImagesWithLimit(pages, displayedPages, 5, (index) {
        setState(() {});
      });
      _scrollController.addListener(() {
        logic.toggleBarsVisibility(_scrollController.offset);
      });
    });

    // Kiểm tra xem manga đã được theo dõi chưa
    checkFollowingStatus(widget.chapter.mangaId);
  }

  // Hàm kiểm tra trạng thái theo dõi
  Future<void> checkFollowingStatus(String mangaId) async {
    final followingStatus = await logic.isFollowingManga(mangaId);
    setState(() {
      isFollowing = followingStatus; // Cập nhật trạng thái theo dõi
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          setState(() {
            logic.areBarsVisible = !logic.areBarsVisible;
          });
        },
        child: Stack(
          children: [
            FutureBuilder<List<String>>(
              future: chapterPages,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('Không có trang nào.'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: displayedPages.length,
                  itemBuilder: (context, index) {
                    final imageUrl = displayedPages[index];
                    if (imageUrl == null) {
                      return Container(
                        color: Colors.grey[300],
                        height: 250,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    return CachedImageWidget(
                      imageUrl: imageUrl,
                      cacheManager: cacheManager,
                    );
                  },
                );
              },
            ),
            // Thanh công cụ
            if (logic.areBarsVisible) ...[
              // Thanh tiêu đề
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black54,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            widget.chapter.chapterName,
                            style: TextStyle(color: Colors.white, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
              // Thanh Taskbar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black54,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => logic.goToPreviousChapter(context, widget.chapter, logic.getCurrentIndex(widget.chapter)),
                      ),
                      IconButton(
                        icon: Icon(Icons.settings, color: Colors.white),
                        onPressed: () {
                          // Xử lý cài đặt
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.home, color: Colors.white),
                        onPressed: () {
                          // Điều hướng về trang chủ
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/home', // Route của trang chủ
                                (Route<dynamic> route) => false, // Xóa hết stack navigation để về trang gốc
                          );
                        },
                      ),
                      // Nút theo dõi
                      IconButton(
                        icon: Icon(
                          Icons.bookmark,
                          color: isFollowing ? Colors.green : Colors.white, // Thay đổi màu sắc dựa trên trạng thái
                        ),
                        onPressed: () async {
                          if (isFollowing) {
                            // Nếu đang theo dõi, bỏ theo dõi
                            await logic.removeFromFollowing(context, widget.chapter.mangaId);
                            setState(() {
                              isFollowing = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã bỏ theo dõi truyện.')));
                          } else {
                            // Nếu không theo dõi, theo dõi manga
                            await logic.followManga(context, widget.chapter.mangaId);
                            setState(() {
                              isFollowing = true;
                            });
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_forward, color: Colors.white),
                        onPressed: () => logic.goToNextChapter(context, widget.chapter, logic.getCurrentIndex(widget.chapter)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

