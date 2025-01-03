//Các Class quản lý UserDB
class User {
  final String id;
  final String googleId;
  final String email;
  final String displayName;
  final String? photoURL;
  final List<String> following;
  final List<ReadingProgress> readingProgress;
  final DateTime createdAt;

  User({
    required this.id,
    required this.googleId,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.following,
    required this.readingProgress,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return User(
        id: json['_id'] ?? '',
        googleId: json['googleId'] ?? '',
        email: json['email'] ?? '',
        displayName: json['displayName'] ?? '',
        photoURL: json['photoURL'],
        following: List<String>.from(json['followingManga'] ?? []),
        readingProgress: (json['readingManga'] as List? ?? [])
            .map((x) => ReadingProgress.fromJson(x))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      );
    } catch (e) {
      print('Error parsing User JSON: $e');
      print('Raw JSON: $json');
      rethrow;
    }
  }
}
class ReadingProgress {
  final String mangaId;
  final int lastChapter;
  final DateTime lastReadAt;

  ReadingProgress({
    required this.mangaId,
    required this.lastChapter,
    required this.lastReadAt,
  });

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    try {
      return ReadingProgress(
        mangaId: json['mangaId'] ?? '',
        lastChapter: json['lastChapter'] ?? 0,
        lastReadAt: DateTime.parse(json['lastReadAt'] ?? DateTime.now().toIso8601String()),
      );
    } catch (e) {
      print('Error parsing ReadingProgress JSON: $e');
      print('Raw JSON: $json');
      rethrow;
    }
  }
}

//Các Class quản lý MangaDB
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

//Các Class quản lý vận hành Frontend
//Chứa các thuộc tính cần để lọc Manga khi fetch data
class SortManga {
  String? title;
  String? status;
  String? safety;
  String? demographic;
  List<String>? includedTags;
  List<String>? excludedTags;
  List<String>? languages;
  String? sortBy;

  // Constructor
  SortManga({
    this.title,
    this.status,
    this.safety,
    this.demographic,
    this.includedTags,
    this.excludedTags,
    this.languages,
    this.sortBy,
  });

  // Hàm xử lý các thuộc tính null
  void handleNullValues() {
    title ??= '';
    status ??= 'Tất cả';
    safety ??= 'Tất cả';
    demographic ??= 'Tất cả';
    includedTags ??= [];
    excludedTags ??= [];
    languages ??= [];
    sortBy ??= 'Mới cập nhật';
  }

  // Hàm chuyển đổi thành params
  Map<String, dynamic> toParams() {
    handleNullValues();
    final params = <String, dynamic>{};

    if (title!.isNotEmpty) params['title'] = title;
    if (status != 'Tất cả') params['status[]'] = [status!.toLowerCase()];
    if (safety != 'Tất cả') params['contentRating[]'] = [safety!.toLowerCase()];
    if (demographic != 'Tất cả') params['publicationDemographic[]'] = [demographic!.toLowerCase()];
    if (includedTags!.isNotEmpty) params['includedTags[]'] = includedTags;
    if (excludedTags!.isNotEmpty) params['excludedTags[]'] = excludedTags;
    if (languages!.isNotEmpty) params['availableTranslatedLanguage[]'] = languages;
    params['order[updatedAt]'] = sortBy == 'Mới cập nhật' ? 'desc' : 'asc';

    return params;
  }
}