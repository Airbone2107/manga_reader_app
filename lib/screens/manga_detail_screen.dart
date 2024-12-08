import 'package:flutter/material.dart';
import '../services/manga_dex_service.dart';
import 'chapter_reader_screen.dart';

class MangaDetailScreen extends StatefulWidget {
  final String mangaId;

  MangaDetailScreen({required this.mangaId});

  @override
  _MangaDetailScreenState createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  late Future<Map<String, dynamic>> mangaDetails;
  late Future<List<dynamic>> chapters;
  late Future<String> coverUrl;

  @override
  void initState() {
    super.initState();
    mangaDetails = MangaDexService().fetchMangaDetails(widget.mangaId);
    chapters = MangaDexService().fetchChapters(widget.mangaId);
    coverUrl = MangaDexService().fetchCoverUrl(widget.mangaId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chi Tiết Manga')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: mangaDetails,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            var details = snapshot.data!;
            String title = details['attributes']['title']['en'] ?? 'Không có tiêu đề';
            String description = details['attributes']['description']['en'] ?? 'Không có mô tả';

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<String>(
                        future: coverUrl,
                        builder: (context, coverSnapshot) {
                          if (coverSnapshot.connectionState == ConnectionState.waiting) {
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
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              description,
                              style: TextStyle(fontSize: 14),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(),
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: chapters,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else {
                        var chapterList = snapshot.data!;

                        // Sắp xếp các chương theo số thứ tự
                        chapterList.sort((a, b) {
                          double chapterA = double.tryParse(a['attributes']['chapter'] ?? '') ?? 0;
                          double chapterB = double.tryParse(b['attributes']['chapter'] ?? '') ?? 0;
                          return chapterA.compareTo(chapterB);
                        });

                        // Tổ chức chương theo ngôn ngữ
                        Map<String, List<dynamic>> chaptersByLanguage = {};
                        for (var chapter in chapterList) {
                          String lang = chapter['attributes']['translatedLanguage'] ?? 'Unknown';
                          if (!chaptersByLanguage.containsKey(lang)) {
                            chaptersByLanguage[lang] = [];
                          }
                          chaptersByLanguage[lang]!.add(chapter);
                        }

                        return ListView(
                          children: chaptersByLanguage.entries.map((entry) {
                            return ExpansionTile(
                              title: Text('Ngôn ngữ: ${entry.key.toUpperCase()}'),
                              children: entry.value.map<Widget>((chapter) {
                                String chapterTitle = chapter['attributes']['title'] ?? '';
                                String chapterNumber = chapter['attributes']['chapter'] ?? 'N/A';

                                // Kiểm tra và thay thế tên chương nếu trùng với số chương
                                String displayTitle = chapterTitle.isEmpty || chapterTitle == chapterNumber
                                    ? 'Chương $chapterNumber'
                                    : 'Chương $chapterNumber: $chapterTitle';

                                return ListTile(
                                  title: Text(displayTitle),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChapterReaderScreen(chapterId: chapter['id']),
                                      ),
                                    );
                                  },

                                );
                              }).toList(),
                            );
                          }).toList(),
                        );
                      }
                    },
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
