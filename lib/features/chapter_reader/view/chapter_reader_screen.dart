// lib/features/chapter_reader/view/chapter_reader_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../data/models/chapter_model.dart';
import '../../../data/services/user_api_service.dart';
import '../logic/chapter_reader_logic.dart';

class ChapterReaderScreen extends StatefulWidget {
  final Chapter chapter;
  ChapterReaderScreen({required this.chapter});

  @override
  _ChapterReaderScreenState createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  late ChapterReaderLogic _logic;
  late Future<List<String>> _chapterPages;
  final ScrollController _scrollController = ScrollController();
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _logic = ChapterReaderLogic(
      userService: UserApiService(), // Sử dụng constructor mặc định
      setState: (fn) {
        if (mounted) setState(fn);
      },
      scrollController: _scrollController,
    );

    _logic.updateProgress(widget.chapter.mangaId, widget.chapter.chapterId);
    _chapterPages = _logic.fetchChapterPages(widget.chapter.chapterId);
    _checkFollowingStatus();
  }

  Future<void> _checkFollowingStatus() async {
    final followingStatus =
        await _logic.isFollowingManga(widget.chapter.mangaId);
    if (mounted) {
      setState(() {
        _isFollowing = followingStatus;
      });
    }
  }

  @override
  void dispose() {
    _logic.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () =>
            setState(() => _logic.areBarsVisible = !_logic.areBarsVisible),
        child: Stack(
          children: [
            FutureBuilder<List<String>>(
              future: _chapterPages,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Lỗi:  ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('Không có trang nào.'));
                }
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    // Sử dụng CachedNetworkImage trực tiếp
                    return CachedNetworkImage(
                      imageUrl: snapshot.data![index],
                      fit: BoxFit.fitWidth,
                      placeholder: (context, url) => Container(
                        height: 300,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 300,
                        child: Center(child: Icon(Icons.error)),
                      ),
                    );
                  },
                );
              },
            ),
            if (_logic.areBarsVisible) _buildOverlay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    int currentIndex = _logic.getCurrentIndex(widget.chapter);
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildAppBar(context),
        _buildBottomNavBar(context, currentIndex),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: Colors.black54,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Text(
                widget.chapter.chapterName,
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(width: 48), // To balance the back button
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context, int currentIndex) {
    return Container(
      color: Colors.black54,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => _logic.goToPreviousChapter(
                context, widget.chapter, currentIndex),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.home, color: Colors.white),
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context, '/', (route) => false),
          ),
          IconButton(
            icon: Icon(
              Icons.bookmark,
              color: _isFollowing ? Colors.green : Colors.white,
            ),
            onPressed: () async {
              if (_isFollowing) {
                await _logic.removeFromFollowing(
                    context, widget.chapter.mangaId);
              } else {
                await _logic.followManga(context, widget.chapter.mangaId);
              }
              _checkFollowingStatus();
            },
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward, color: Colors.white),
            onPressed: () =>
                _logic.goToNextChapter(context, widget.chapter, currentIndex),
          ),
        ],
      ),
    );
  }
}
