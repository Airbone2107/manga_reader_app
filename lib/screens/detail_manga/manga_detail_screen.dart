import 'package:flutter/material.dart';
import '../../local_storage/secure_user_manager.dart';
import '../../services/manga_dex_service.dart';
import '../../services/manga_user_service.dart';
import '../../services/model.dart';
import '../chapter/chapter_reader_screen.dart';

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
  bool isFollowing = false;

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

    // Kiểm tra trạng thái theo dõi
    checkFollowingStatus();
  }

  Future<void> checkFollowingStatus() async {
    bool following = await isFollowingManga(widget.mangaId);
    setState(() {
      isFollowing = following;
    });
  }

  Future<void> toggleFollowStatus() async {
    if (isFollowing) {
      await removeFromFollowing(context, widget.mangaId);
    } else {
      await followManga(context, widget.mangaId);
    }
    checkFollowingStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chi Tiết Manga'),
        actions: [
          IconButton(
            icon: Icon(
              isFollowing ? Icons.bookmark : Icons.bookmark_outline,
              color: isFollowing ? Colors.green : Colors.red,
            ),
            onPressed: toggleFollowStatus,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: mangaDetails,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            var details = snapshot.data ?? {};
            var attributes = details['attributes'] ?? {};

            String title = (attributes['title']?['en'] ?? 'Không có tiêu đề') as String;
            String description = (attributes['description']?['en'] ?? 'Không có mô tả') as String;
            String status = (attributes['status'] ?? 'Không xác định') as String;
            int? year = attributes['year'] as int?;
            String contentRating = (attributes['contentRating'] ?? 'Không rõ') as String;

            List<dynamic> tags = (attributes['tags'] as List<dynamic>? ?? [])
                .map((tag) => tag['attributes']?['name']?['en'] ?? 'Không rõ')
                .toList();

            Map<String, String> links = (attributes['links'] as Map<String, dynamic>? ?? {})
                .map((key, value) => MapEntry(key, value.toString()));

            // Lấy thông tin tác giả
            List<dynamic>? relationships = details['relationships'] as List<dynamic>?;
            List<dynamic> authors = relationships?.where((relation) => relation['type'] == 'author').toList() ?? [];
            String authorNames = authors.isNotEmpty
                ? authors.map((author) => author['attributes']?['name'] ?? 'Không rõ').join(', ')
                : 'Không rõ';

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
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: Row(
                                        children: [
                                          Icon(Icons.info, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('Thông tin chi tiết')
                                        ],
                                      ),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Tiêu đề:',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text(title, style: TextStyle(fontSize: 14)),
                                            SizedBox(height: 8),
                                            Text('Tác giả:',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text(authorNames, style: TextStyle(fontSize: 14)),
                                            SizedBox(height: 8),
                                            Text('Mô tả:',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text(description, style: TextStyle(fontSize: 14)),
                                            SizedBox(height: 8),
                                            Text('Trạng thái:',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text(status, style: TextStyle(fontSize: 14)),
                                            SizedBox(height: 8),
                                            Text('Năm phát hành:',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text('${year ?? 'Không rõ'}', style: TextStyle(fontSize: 14)),
                                            SizedBox(height: 8),
                                            Text('Đánh giá nội dung:',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text(contentRating, style: TextStyle(fontSize: 14)),
                                            SizedBox(height: 8),
                                            Text('Thể loại:',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            ...tags.map((tag) => Padding(
                                              padding: const EdgeInsets.only(left: 8.0),
                                              child: Text('- $tag', style: TextStyle(fontSize: 14)),
                                            )),
                                            SizedBox(height: 8),
                                            if (links.isNotEmpty)
                                              Text('Liên kết liên quan:',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            ...links.entries.map((entry) => Padding(
                                              padding: const EdgeInsets.only(left: 8.0),
                                              child: Text('${entry.key}: ${entry.value}',
                                                  style: TextStyle(fontSize: 14)),
                                            )),
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
                              },
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

Future<void> followManga(BuildContext context, String mangaId) async {
  try {
    final token = await StorageService.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng đăng nhập để theo dõi truyện.')),
      );
      return;
    }

    await UserService(baseUrl: 'https://manga-reader-app-backend.onrender.com').addToFollowing(mangaId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã thêm truyện vào danh sách theo dõi.')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi khi thêm truyện: $e')),
    );
  }
}

Future<void> removeFromFollowing(BuildContext context, String mangaId) async {
  try {
    final token = await StorageService.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng đăng nhập để bỏ theo dõi truyện.')),
      );
      return;
    }

    await UserService(baseUrl: 'https://manga-reader-app-backend.onrender.com').removeFromFollowing(mangaId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã bỏ theo dõi truyện.')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi khi bỏ theo dõi truyện: $e')),
    );
  }
}

Future<bool> isFollowingManga(String mangaId) async {
  try {
    final token = await StorageService.getToken();
    if (token == null) {
      return false;
    }

    return await UserService(baseUrl: 'https://manga-reader-app-backend.onrender.com').checkIfUserIsFollowing(mangaId);
  } catch (e) {
    print("Lỗi khi kiểm tra theo dõi: $e");
    return false;
  }
}
