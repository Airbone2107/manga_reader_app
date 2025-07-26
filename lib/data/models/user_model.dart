// lib/data/models/user_model.dart
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
    return User(
      id: json['_id'] as String? ?? '',
      googleId: json['googleId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      photoURL: json['photoURL'] as String?,
      following: List<String>.from(json['followingManga'] as List? ?? []),
      readingProgress: (json['readingManga'] as List? ?? [])
          .map((x) => ReadingProgress.fromJson(x as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ReadingProgress {
  final String mangaId;
  final String lastChapter;
  final DateTime lastReadAt;

  ReadingProgress({
    required this.mangaId,
    required this.lastChapter,
    required this.lastReadAt,
  });

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      mangaId: json['mangaId'] as String? ?? '',
      lastChapter: json['lastChapter'] as String? ?? '',
      lastReadAt: DateTime.tryParse(json['lastReadAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
