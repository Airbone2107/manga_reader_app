// lib/features/detail_manga/logic/manga_detail_logic.dart
import 'package:flutter/material.dart';
import '../../../data/services/mangadex_api_service.dart';
import '../../../data/services/user_api_service.dart';
import '../../../data/storage/secure_storage_service.dart';

class MangaDetailLogic {
  final String mangaId;
  final VoidCallback refreshUI;

  final MangaDexApiService _mangaDexService = MangaDexApiService();
  final UserApiService _userApiService =
      UserApiService(); // Không cần truyền baseUrl

  late Future<Map<String, dynamic>> mangaDetails;
  late Future<List<dynamic>> chapters;
  late Future<String> coverUrl;
  bool isFollowing = false;

  MangaDetailLogic({required this.mangaId, required this.refreshUI}) {
    _init();
  }

  void _init() {
    List<String> defaultLanguages = ['en', 'vi'];
    mangaDetails = _mangaDexService.fetchMangaDetails(mangaId);
    chapters = _mangaDexService.fetchChapters(
      mangaId,
      defaultLanguages.join(','),
    );
    coverUrl = _mangaDexService.fetchCoverUrl(mangaId);
    checkFollowingStatus();
  }

  Future<void> checkFollowingStatus() async {
    try {
      final token = await SecureStorageService.getToken();
      if (token == null) {
        isFollowing = false;
        refreshUI();
        return;
      }
      bool following = await _userApiService.checkIfUserIsFollowing(mangaId);
      isFollowing = following;
      refreshUI();
    } catch (e) {
      print("Lỗi khi kiểm tra theo dõi: $e");
      isFollowing = false;
      refreshUI();
    }
  }

  Future<void> toggleFollowStatus(BuildContext context) async {
    final token = await SecureStorageService.getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng đăng nhập để theo dõi truyện.')),
      );
      return;
    }

    try {
      if (isFollowing) {
        await _userApiService.removeFromFollowing(mangaId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã bỏ theo dõi truyện.')),
        );
      } else {
        await _userApiService.addToFollowing(mangaId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm truyện vào danh sách theo dõi.')),
        );
      }
      await checkFollowingStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }
}
