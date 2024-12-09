import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../services/manga_dex_service.dart';

class CachedImageWidget extends StatefulWidget {
  final String imageUrl;
  final CacheManager cacheManager;

  CachedImageWidget({required this.imageUrl, required this.cacheManager});

  @override
  _CachedImageWidgetState createState() => _CachedImageWidgetState();
}

class _CachedImageWidgetState extends State<CachedImageWidget>
    with AutomaticKeepAliveClientMixin {
  late Future<Image> _cachedImage;

  @override
  void initState() {
    super.initState();
    _cachedImage = _loadImage(widget.imageUrl);
  }

  Future<Image> _loadImage(String url) async {
    final file = await widget.cacheManager.getSingleFile(url);
    return Image.file(file, fit: BoxFit.fitWidth);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Bắt buộc khi dùng AutomaticKeepAliveClientMixin
    return FutureBuilder<Image>(
      future: _cachedImage,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Hiển thị khung ảnh với màu cơ bản và biểu tượng loading
          return Container(
            color: Colors.grey[300],
            height: 300, // Chiều cao khung ảnh tạm thời
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasError) {
          // Hiển thị khung ảnh lỗi với màu cơ bản và biểu tượng lỗi
          return Container(
            color: Colors.grey[300],
            height: 300, // Chiều cao khung ảnh tạm thời
            child: Center(
              child: Icon(Icons.broken_image, color: Colors.grey),
            ),
          );
        } else {
          // Hiển thị ảnh đã tải thành công
          return snapshot.data!;
        }
      },
    );
  }
}

class ChapterReaderScreen extends StatefulWidget {
  final String chapterId;

  ChapterReaderScreen({required this.chapterId});

  @override
  _ChapterReaderScreenState createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  final CacheManager cacheManager = DefaultCacheManager();
  late Future<List<String>> chapterPages; // Danh sách URL của tất cả các trang
  final List<String?> displayedPages = []; // Danh sách các trang đang hiển thị
  int currentPageIndex = 0; // Chỉ mục của trang đã hiển thị cuối cùng
  final int loadBatchSize = 10; // Số trang tải mỗi lần
  bool isLoading = false; // Trạng thái tải trang tiếp theo

  @override
  void initState() {
    super.initState();
    chapterPages = MangaDexService().fetchChapterPages(widget.chapterId);

    // Bắt đầu tải trang
    chapterPages.then((pages) {
      _loadNextBatch(pages);
    });
  }

  void _loadNextBatch(List<String> pages) async {
    if (isLoading || currentPageIndex >= pages.length) return;

    setState(() {
      isLoading = true;

      // Tính số lượng ảnh sẽ tải
      final nextBatchCount = (currentPageIndex + loadBatchSize).clamp(0, pages.length) - currentPageIndex;

      // Thêm placeholder vào danh sách
      displayedPages.addAll(List.filled(nextBatchCount, null));
    });

    final batchStartIndex = currentPageIndex;
    final batchEndIndex = (currentPageIndex + loadBatchSize).clamp(0, pages.length);

    for (int i = batchStartIndex; i < batchEndIndex; i++) {
      if (!mounted) return; // Kiểm tra nếu widget đã bị hủy

      try {
        final imageUrl = pages[i];

        // Tải ảnh về cache
        await cacheManager.getSingleFile(imageUrl);

        // Cập nhật URL ảnh vào danh sách nếu còn trong giới hạn
        if (!mounted) return;
        setState(() {
          if (i < displayedPages.length) {
            displayedPages[i] = imageUrl;
          }
        });
      } catch (error) {
        // Giữ placeholder nếu lỗi tải ảnh
        if (!mounted) return;
        setState(() {
          if (i < displayedPages.length) {
            displayedPages[i] = null; // Placeholder khi lỗi
          }
        });
      }
    }

    if (!mounted) return;

    setState(() {
      currentPageIndex = batchEndIndex;
      isLoading = false;
    });
  }



  @override
  void dispose() {
    cacheManager.emptyCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Đọc Chương'),
      ),
      body: FutureBuilder<List<String>>(
        future: chapterPages,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Không có trang nào.'));
          }

          final allPages = snapshot.data!;

          return NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (!isLoading &&
                  notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent - 200) {
                _loadNextBatch(allPages);
              }
              return true;
            },
            child: ListView.builder(
              itemCount: displayedPages.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= displayedPages.length) {
                  return SizedBox.shrink(); // Trả về widget trống nếu truy cập ngoài phạm vi
                }

                final imageUrl = displayedPages[index];
                if (imageUrl == null) {
                  // Placeholder khi ảnh đang được tải
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

            ),
          );
        },
      ),
    );
  }
}
