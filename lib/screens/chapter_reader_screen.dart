import 'package:flutter/material.dart';
import '../services/image_loader.dart';
import '../services/manga_dex_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ChapterReaderScreen extends StatefulWidget {
  final String chapterId;
  final String chapterName;
  final List<dynamic> chapterList; // Thêm danh sách chương

  ChapterReaderScreen({required this.chapterId, required this.chapterName, required this.chapterList});

  @override
  _ChapterReaderScreenState createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  final CacheManager cacheManager = DefaultCacheManager();
  late Future<List<String>> chapterPages;
  List<String?> displayedPages = [];
  late ImageLoader imageLoader;
  bool areBarsVisible = true;
  final ScrollController _scrollController = ScrollController();
  double scrollThreshold = 0.0;
  double lastOffset = 0.0;
  late int currentIndex; // Chỉ số chương hiện tại

  @override
  void initState() {
    super.initState();
    // Tìm vị trí của chương hiện tại trong danh sách
    currentIndex = widget.chapterList.indexWhere((chapter) => chapter['id'] == widget.chapterId);
    chapterPages = MangaDexService().fetchChapterPages(widget.chapterId);
    chapterPages.then((pages) {
      setState(() {
        displayedPages = List.filled(pages.length, null);
      });

      imageLoader = ImageLoader(cacheManager: cacheManager);
      imageLoader.loadImagesWithLimit(
        pages,
        displayedPages,
        5,
            (index) {
          setState(() {});
        },
      );

      _scrollController.addListener(() {
        double currentOffset = _scrollController.offset;
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
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    scrollThreshold = MediaQuery.of(context).size.height / 4;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    cacheManager.emptyCache();
    super.dispose();
  }

  String getChapterDisplayName(Map<String, dynamic> chapter) {
    String chapterNumber = chapter['attributes']['chapter'] ?? 'N/A';
    String chapterTitle = chapter['attributes']['title'] ?? '';
    return chapterTitle.isEmpty || chapterTitle == chapterNumber
        ? 'Chương $chapterNumber'
        : 'Chương $chapterNumber: $chapterTitle';
  }

  void goToNextChapter() {
    if (currentIndex > 0) {
      var prevChapter = widget.chapterList[currentIndex - 1];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChapterReaderScreen(
            chapterId: prevChapter['id'],
            chapterName: getChapterDisplayName(prevChapter),
            chapterList: widget.chapterList,
          ),
        ),
      );
    }
  }

  void goToPreviousChapter() {
    if (currentIndex < widget.chapterList.length - 1) {
      var nextChapter = widget.chapterList[currentIndex + 1];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChapterReaderScreen(
            chapterId: nextChapter['id'],
            chapterName: getChapterDisplayName(nextChapter),
            chapterList: widget.chapterList,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          setState(() {
            areBarsVisible = !areBarsVisible;
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
            if (areBarsVisible)
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
                            widget.chapterName,
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
            if (areBarsVisible)
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
                        onPressed: goToPreviousChapter, // Chuyển đến chương trước
                      ),
                      IconButton(
                        icon: Icon(Icons.settings, color: Colors.white),
                        onPressed: () {
                          // Handle settings action
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.home, color: Colors.white),
                        onPressed: () {
                          // Handle home action
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.bookmark, color: Colors.white),
                        onPressed: () {
                          // Handle follow story action
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_forward, color: Colors.white),
                        onPressed: goToNextChapter, // Chuyển đến chương tiếp theo
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

