// lib/features/detail_manga/view/manga_detail_screen.dart
import 'package:flutter/material.dart';
import '../../../data/models/chapter_model.dart';
import '../../chapter_reader/view/chapter_reader_screen.dart';
import '../logic/manga_detail_logic.dart';

class MangaDetailScreen extends StatefulWidget {
  final String mangaId;
  MangaDetailScreen({required this.mangaId});

  @override
  _MangaDetailScreenState createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  late MangaDetailLogic _logic;

  @override
  void initState() {
    super.initState();
    _logic = MangaDetailLogic(
      mangaId: widget.mangaId,
      refreshUI: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chi Tiết Manga'),
        actions: [
          IconButton(
            icon: Icon(
              _logic.isFollowing ? Icons.bookmark : Icons.bookmark_outline,
              color: _logic.isFollowing ? Colors.green : Colors.white,
            ),
            onPressed: () => _logic.toggleFollowStatus(context),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _logic.mangaDetails,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('Không có dữ liệu'));
          } else {
            return _buildContent(snapshot.data!);
          }
        },
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> details) {
    var attributes = details['attributes'] ?? {};
    String title = (attributes['title']?['en'] ?? 'Không có tiêu đề') as String;
    String description =
        (attributes['description']?['en'] ?? 'Không có mô tả') as String;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<String>(
                future: _logic.coverUrl,
                builder: (context, coverSnapshot) {
                  if (coverSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return SizedBox(
                      width: MediaQuery.of(context).size.width / 3,
                      height: 150,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else if (coverSnapshot.hasError) {
                    return Icon(Icons.broken_image, size: 100);
                  } else {
                    return Image.network(
                      coverSnapshot.data!,
                      width: MediaQuery.of(context).size.width / 3,
                      height: 150,
                      fit: BoxFit.cover,
                    );
                  }
                },
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showFullDetailsDialog(details),
                      child: Text(
                        description,
                        style: TextStyle(fontSize: 14),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(),
        Expanded(
          child: _buildChapterList(),
        ),
      ],
    );
  }

  void _showFullDetailsDialog(Map<String, dynamic> details) {
    var attributes = details['attributes'] ?? {};
    String title = (attributes['title']?['en'] ?? 'Không có tiêu đề') as String;
    String description =
        (attributes['description']?['en'] ?? 'Không có mô tả') as String;
    String status = (attributes['status'] ?? 'Không xác định') as String;
    int? year = attributes['year'] as int?;
    String contentRating =
        (attributes['contentRating'] ?? 'Không rõ') as String;
    List<dynamic> tags = (attributes['tags'] as List<dynamic>? ?? [])
        .map((tag) => tag['attributes']?['name']?['en'] ?? 'Không rõ')
        .toList();
    List<dynamic>? relationships = details['relationships'] as List<dynamic>?;
    List<dynamic> authors = relationships
            ?.where((relation) => relation['type'] == 'author')
            .toList() ??
        [];
    String authorNames = authors.isNotEmpty
        ? authors
            .map((author) => author['attributes']?['name'] ?? 'Không rõ')
            .join(', ')
        : 'Không rõ';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 8),
            Text('Thông tin chi tiết')
          ]),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Tác giả:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(authorNames),
                SizedBox(height: 8),
                Text('Mô tả:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(description),
                SizedBox(height: 8),
                Text('Trạng thái:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(status),
                SizedBox(height: 8),
                Text('Thể loại:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...tags.map((tag) => Text('- $tag')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Đóng', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChapterList() {
    return FutureBuilder<List<dynamic>>(
      future: _logic.chapters,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('Không có chương nào.'));
        } else {
          var chapterList = snapshot.data!;
          Map<String, List<dynamic>> chaptersByLanguage = {};
          for (var chapter in chapterList) {
            String lang =
                chapter['attributes']['translatedLanguage'] ?? 'Unknown';
            chaptersByLanguage.putIfAbsent(lang, () => []).add(chapter);
          }

          return ListView(
            children: chaptersByLanguage.entries.map((langEntry) {
              String language = langEntry.key;
              List<dynamic> languageChapters = langEntry.value;
              return ExpansionTile(
                title: Text('Ngôn ngữ: ${language.toUpperCase()}'),
                children: languageChapters.map<Widget>((chapter) {
                  String chapterTitle = chapter['attributes']['title'] ?? '';
                  String chapterNumber =
                      chapter['attributes']['chapter'] ?? 'N/A';
                  String displayTitle =
                      chapterTitle.isEmpty || chapterTitle == chapterNumber
                          ? 'Chương $chapterNumber'
                          : 'Chương $chapterNumber: $chapterTitle';

                  return ListTile(
                    title: Text(displayTitle),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChapterReaderScreen(
                          chapter: Chapter(
                            mangaId: widget.mangaId,
                            chapterId: chapter['id'],
                            chapterName: displayTitle,
                            chapterList: languageChapters,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          );
        }
      },
    );
  }
}
