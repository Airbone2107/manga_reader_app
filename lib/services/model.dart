// lib/services/model.dart
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