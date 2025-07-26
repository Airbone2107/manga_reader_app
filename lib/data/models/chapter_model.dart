// lib/data/models/chapter_model.dart
class Chapter {
  final String mangaId;
  final String chapterId;
  final String chapterName;
  final List<dynamic> chapterList;

  Chapter({
    required this.mangaId,
    required this.chapterId,
    required this.chapterName,
    required this.chapterList,
  });
}
