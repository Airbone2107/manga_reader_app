import 'package:flutter/material.dart';
import '../services/image_loader.dart';
import '../services/manga_dex_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ChapterReaderScreen extends StatefulWidget {
  final String chapterId;

  ChapterReaderScreen({required this.chapterId});

  @override
  _ChapterReaderScreenState createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  final CacheManager cacheManager = DefaultCacheManager();
  late Future<List<String>> chapterPages;
  List<String?> displayedPages = [];
  late ImageLoader imageLoader;

  @override
  void initState() {
    super.initState();
    chapterPages = MangaDexService().fetchChapterPages(widget.chapterId);
    chapterPages.then((pages) {
      setState(() {
        displayedPages = List.filled(pages.length, null);
      });

      imageLoader = ImageLoader(cacheManager: cacheManager);
      imageLoader.loadImagesWithLimit(
        pages,
        displayedPages,
        5, // Giới hạn số lượng ảnh tải đồng thời
            (index) {
          setState(() {});
        },
      );
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

          return ListView.builder(
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
    );
  }
}

