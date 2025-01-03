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
  final CacheManager cacheManager = DefaultCacheManager(); // Quản lý bộ nhớ đệm cho hình ảnh.
  late Future<List<String>> chapterPages; // Danh sách URL của các trang truyện.
  List<String?> displayedPages = []; // Danh sách URL các trang đã được hiển thị.
  late ImageLoader imageLoader; // Hỗ trợ tải hình ảnh với giới hạn.
  final ScrollController _scrollController = ScrollController(); // Quản lý cuộn nội dung.
  late ChapterReaderLogic logic; // Logic xử lý chức năng màn hình.

  /// Khởi tạo trạng thái ban đầu.
  @override
  void initState() {
    super.initState();
    logic = ChapterReaderLogic(
      userService: UserService(baseUrl: 'https://manga-reader-app-backend.onrender.com'), // Dịch vụ người dùng.
      setState: setState,
      scrollController: _scrollController,
    );

    chapterPages = logic.fetchChapterPages(widget.chapter.chapterId); // Lấy danh sách trang trong chương hiện tại.
    chapterPages.then((pages) {
      setState(() {
        displayedPages = List.filled(pages.length, null); // Khởi tạo danh sách trống với số lượng trang.
      });

      imageLoader = ImageLoader(cacheManager: cacheManager); // Khởi tạo ImageLoader.
      imageLoader.loadImagesWithLimit(pages, displayedPages, 5 /* Giới hạn tải ảnh */, (index) {
          setState(() {}); // Cập nhật giao diện khi tải xong hình ảnh.
        },
      );
      _scrollController.addListener(() {
        logic.toggleBarsVisibility(_scrollController.offset); // Hiển thị/Ẩn thanh công cụ khi cuộn.
      });
    });
  }

  /// Xây dựng giao diện đọc truyện.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          setState(() {
            logic.areBarsVisible = !logic.areBarsVisible; // Ẩn/Hiện thanh công cụ khi chạm vào màn hình.
          });
        },
        child: Stack(
          children: [
            //
            FutureBuilder<List<String>>(
              future: chapterPages, // Xây dựng nội dung dựa trên các trang truyện có trong chương.
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator()); // Hiển thị vòng xoay khi đang tải.
                } else if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}')); // Thông báo lỗi nếu có.
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('Không có trang nào.')); // Thông báo nếu không có trang.
                }

                return ListView.builder(
                  controller: _scrollController, // Quản lý cuộn trang.
                  itemCount: displayedPages.length, // Số lượng trang.
                  itemBuilder: (context, index) {
                    final imageUrl = displayedPages[index];
                    if (imageUrl == null) {
                      return Container(
                        color: Colors.grey[300], // Hiển thị nền xám khi trang chưa tải xong.
                        height: 250,
                        child: Center(child: CircularProgressIndicator()), // Hiển thị vòng xoay khi tải.
                      );
                    }

                    return CachedImageWidget(
                      imageUrl: imageUrl, // Hiển thị hình ảnh đã được lưu trữ trong bộ nhớ đệm.
                      cacheManager: cacheManager,
                    );
                  },
                );
              },
            ),

            // Thanh công cụ.
            if (logic.areBarsVisible) ...[
              //Thanh tiêu đề chapter
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black54, // Thanh trên cùng có nền đen mờ.
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white), // Nút quay lại.
                        onPressed: () {
                          Navigator.pop(context); // Quay lại màn hình trước.
                        },
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            widget.chapter.chapterName, // Hiển thị tên chương.
                            style: TextStyle(color: Colors.white, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      SizedBox(width: 48), // Khoảng trống để căn giữa.
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
                  color: Colors.black54, // Thanh dưới cùng có nền đen mờ.
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Nút quay về chapter trước đó
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white), // Nút chương trước.
                        onPressed: () => logic.goToPreviousChapter(context, widget.chapter, logic.getCurrentIndex(widget.chapter)),
                      ),
                      // Nút cài đặt
                      IconButton(
                        icon: Icon(Icons.settings, color: Colors.white), // Nút cài đặt.
                        onPressed: () {
                          // Xử lý cài đặt.
                        },
                      ),
                      // Nút quay về trang chủ
                      IconButton(
                        icon: Icon(Icons.home, color: Colors.white), // Nút về trang chủ.
                        onPressed: () {
                          // Xử lý về trang chủ.
                        },
                      ),
                      // Nút theo dõi truyện
                      IconButton(
                        icon: Icon(Icons.bookmark, color: Colors.white), // Nút đánh dấu.
                        onPressed: () => logic.followManga(context, widget.chapter.mangaId),
                      ),
                      // Nút sang chapter tiếp theo
                      IconButton(
                        icon: Icon(Icons.arrow_forward, color: Colors.white), // Nút chương sau.
                        onPressed: () => logic.goToNextChapter(context, widget.chapter, logic.getCurrentIndex(widget.chapter)),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ],
        ),
      ),
    );
  }
}
