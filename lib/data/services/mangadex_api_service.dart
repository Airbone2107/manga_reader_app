// lib/data/services/mangadex_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sort_manga_model.dart';

class MangaDexApiService {
  final String baseUrl = 'https://api.mangadex.org';

  // Ghi log lỗi với thông tin chi tiết
  void logError(String functionName, http.Response response) {
    print('Lỗi trong hàm $functionName:');
    print('Mã trạng thái: ${response.statusCode}');
    print('Nội dung phản hồi: ${response.body}');
  }

  Future<List<dynamic>> fetchManga({
    int? limit,
    int? offset,
    SortManga? sortManga,
  }) async {
    Map<String, dynamic> params = {};

    if (limit != null) params['limit'] = limit.toString();
    if (offset != null) params['offset'] = offset.toString();

    if (sortManga != null) {
      params.addAll(sortManga.toParams());
    }

    final uri = Uri.parse('$baseUrl/manga').replace(queryParameters: params);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['data'];
    } else if (response.statusCode == 503) {
      throw Exception(
          'Máy chủ MangaDex hiện đang bảo trì, xin vui lòng thử lại sau!');
    } else {
      logError('fetchManga', response);
      throw Exception('Lỗi khi tải manga: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> fetchMangaDetails(String mangaId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/manga/$mangaId?includes[]=author'));

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['data'];
    } else {
      logError('fetchMangaDetails', response);
      throw Exception('Lỗi khi tải chi tiết manga');
    }
  }

  Future<List<dynamic>> fetchChapters(String mangaId, String languages,
      {String order = 'desc', int? maxChapters}) async {
    List<String> languageList =
        languages.split(',').map((lang) => lang.trim()).toList();
    languageList.removeWhere(
        (lang) => !RegExp(r'^[a-z]{2}(-[a-z]{2})?$').hasMatch(lang));

    if (languageList.isEmpty) {
      throw Exception(
          'Danh sách ngôn ngữ không hợp lệ. Vui lòng kiểm tra cài đặt.');
    }

    List<dynamic> allChapters = [];
    int offset = 0;
    int limit = 100;

    while (true) {
      final response = await http.get(Uri.parse(
          '$baseUrl/manga/$mangaId/feed?limit=$limit&offset=$offset&translatedLanguage[]=${languageList.join('&translatedLanguage[]=')}&order[chapter]=$order'));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        var chapters = data['data'];

        if (chapters.isEmpty) {
          break;
        }

        allChapters.addAll(chapters);

        if (maxChapters != null && allChapters.length >= maxChapters) {
          return allChapters.take(maxChapters).toList();
        }

        offset += limit;
      } else if (response.statusCode == 503) {
        throw Exception(
            'Máy chủ MangaDex hiện đang bảo trì, xin vui lòng thử lại sau!');
      } else {
        logError('fetchChapters', response);
        throw Exception(
            'Lỗi trong hàm fetchChapters:\nMã trạng thái: ${response.statusCode}\nNội dung phản hồi: ${response.body}');
      }
    }

    return allChapters;
  }

  Future<String> fetchCoverUrl(String mangaId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/cover?manga[]=$mangaId'));

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      if (data['data'] != null && data['data'].isNotEmpty) {
        String coverId = data['data'][0]['attributes']['fileName'];
        return 'https://uploads.mangadex.org/covers/$mangaId/$coverId.512.jpg';
      } else {
        logError('fetchCoverUrl', response);
        throw Exception('Không tìm thấy ảnh bìa');
      }
    } else {
      logError('fetchCoverUrl', response);
      throw Exception('Lỗi khi tải ảnh bìa');
    }
  }

  Future<List<String>> fetchChapterPages(String chapterId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/at-home/server/$chapterId'));

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      List<String> pages = List<String>.from(data['chapter']['data']);
      String baseUrl = data['baseUrl'];
      String hash = data['chapter']['hash'];
      return pages.map((page) => '$baseUrl/data/$hash/$page').toList();
    } else {
      logError('fetchChapterPages', response);
      throw Exception('Lỗi khi tải các trang chương');
    }
  }

  Future<List<dynamic>> fetchTags() async {
    final response = await http.get(Uri.parse('$baseUrl/manga/tag'));

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['data'] ?? [];
    } else {
      logError('fetchTags', response);
      throw Exception('Lỗi khi tải danh sách tags');
    }
  }

  Future<List<dynamic>> fetchMangaByIds(List<String> mangaIds) async {
    if (mangaIds.isEmpty) return [];

    final String idsQuery = mangaIds.join('&ids[]=');
    final Uri url = Uri.parse('$baseUrl/manga?ids[]=$idsQuery');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to fetch manga: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error fetching manga: $error');
    }
  }
}
