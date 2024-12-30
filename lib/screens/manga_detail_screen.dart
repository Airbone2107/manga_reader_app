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

    // Mặc định ngôn ngữ là "en" và "vi"
    List<String> defaultLanguages = ['en', 'vi'];
    mangaDetails = MangaDexService().fetchMangaDetails(widget.mangaId);
    chapters = MangaDexService().fetchChapters(
      widget.mangaId,
      defaultLanguages.join(','),
    );
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

                        // Organize chapters by language
                        Map<String, List<dynamic>> chaptersByLanguage = {};
                        for (var chapter in chapterList) {
                          String lang = chapter['attributes']['translatedLanguage'] ?? 'Unknown';
                          chaptersByLanguage.putIfAbsent(lang, () => []);
                          chaptersByLanguage[lang]!.add(chapter);
                        }

                        return ListView(
                          children: chaptersByLanguage.entries.map((langEntry) {
                            String language = langEntry.key;
                            List<dynamic> languageChapters = langEntry.value;

                            // Group chapters by volume for display
                            Map<String, List<dynamic>> chaptersByVolume = {};
                            for (var chapter in languageChapters) {
                              String volume = chapter['attributes']['volume'] ?? 'Không xác định';
                              chaptersByVolume.putIfAbsent(volume, () => []);
                              chaptersByVolume[volume]!.add(chapter);
                            }

                            return ExpansionTile(
                              title: Text('Ngôn ngữ: ${language.toUpperCase()}'),
                              children: chaptersByVolume.entries.map((volEntry) {
                                String volume = volEntry.key;
                                List<dynamic> volumeChapters = volEntry.value;

                                return ExpansionTile(
                                  title: Text('Tập: $volume'),
                                  children: volumeChapters.map<Widget>((chapter) {
                                    String chapterTitle = chapter['attributes']['title'] ?? '';
                                    String chapterNumber = chapter['attributes']['chapter'] ?? 'N/A';

                                    String displayTitle =
                                    chapterTitle.isEmpty || chapterTitle == chapterNumber
                                        ? 'Chương $chapterNumber'
                                        : 'Chương $chapterNumber: $chapterTitle';

                                    return ListTile(
                                      title: Text(displayTitle),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChapterReaderScreen(
                                              mangaId: widget.mangaId,
                                              chapterId: chapter['id'],
                                              chapterName: displayTitle,
                                              chapterList: languageChapters, // Pass chapters by language
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
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