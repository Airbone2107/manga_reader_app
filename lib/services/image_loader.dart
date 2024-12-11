import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// CachedImageWidget - Không thay đổi, chỉ là widget hiển thị ảnh đã được tải
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
    super.build(context);
    return FutureBuilder<Image>(
      future: _cachedImage,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey[300],
            height: 300,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasError) {
          return Container(
            color: Colors.grey[300],
            height: 300,
            child: Center(
              child: Icon(Icons.broken_image, color: Colors.grey),
            ),
          );
        } else {
          return snapshot.data!;
        }
      },
    );
  }
}

// Tạo class ImageLoader để xử lý việc tải ảnh
class ImageLoader {
  final CacheManager cacheManager;
  ImageLoader({required this.cacheManager});

  Future<void> loadImagesWithLimit(
    List<String> pages,
    List<String?> displayedPages,
    int maxConcurrentDownloads,
    ValueChanged<int> onImageLoaded,
  ) async {
    int currentPageIndex = 0;
    bool isLoading = false;

    Future<void> _loadImage(String imageUrl, int index) async {
      try {
        displayedPages[index] = imageUrl;
        onImageLoaded(index); // Cập nhật giao diện
      } catch (error) {
        displayedPages[index] = null; // Giữ placeholder nếu lỗi
        onImageLoaded(index); // Cập nhật giao diện
      }
    }

    // Tải ảnh song song với giới hạn tối đa mỗi lần
    while (currentPageIndex < pages.length) {
      if (isLoading) return;

      isLoading = true;
      final futures = <Future>[];

      // Tải ảnh song song nhưng giới hạn số lượng tải đồng thời
      for (int i = currentPageIndex;
          i < pages.length && futures.length < maxConcurrentDownloads;
          i++) {
        futures.add(_loadImage(pages[i], i));
        currentPageIndex = i + 1;
      }

      await Future.wait(futures);
      isLoading = false;
    }
  }
}
