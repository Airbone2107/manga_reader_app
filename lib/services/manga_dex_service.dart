import 'dart:convert';
import 'package:http/http.dart' as http;

class MangaDexService {
  final String baseUrl = 'https://api.mangadex.org';

  // Ghi log lỗi với thông tin chi tiết
  void logError(String functionName, http.Response response) {
    print('Lỗi trong hàm $functionName:');
    print('Mã trạng thái: ${response.statusCode}');
    print('Nội dung phản hồi: ${response.body}');
    // Bạn có thể thêm các thông tin chi tiết khác nếu cần.
  }

  // Lấy danh sách manga
  Future<List<dynamic>> fetchMangaList(
      {required int limit, required int offset}) async {
    final response =
        await http.get(Uri.parse('$baseUrl/manga?limit=$limit&offset=$offset'));

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['data']; // Trả về danh sách manga
    } else if (response.statusCode == 503) {
      // Nếu gặp lỗi 503 (Bảo trì), ném lỗi với thông báo cụ thể
      throw Exception(
          'Máy chủ MangaDex hiện đang bảo trì, xin vui lòng thử lại sau!');
    } else {
      logError('fetchMangaList',
          response); // Ghi log lỗi nếu không phải mã trạng thái 200 hoặc 503
      throw Exception(
          'Lỗi khi tải manga với mã trạng thái: ${response.statusCode}');
    }
  }

  // Lấy chi tiết một manga
  Future<Map<String, dynamic>> fetchMangaDetails(String mangaId) async {
    final response = await http.get(Uri.parse('$baseUrl/manga/$mangaId'));

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['data'];
    } else {
      logError('fetchMangaDetails', response);
      throw Exception('Lỗi khi tải chi tiết manga');
    }
  }

  // Lấy danh sách các chương của manga với Pagination
  Future<List<dynamic>> fetchChapters(String mangaId) async {
    List<dynamic> allChapters = [];
    int offset = 0;
    int limit = 100; // Bạn có thể điều chỉnh limit tùy theo nhu cầu

    while (true) {
      final response = await http.get(Uri.parse(
          '$baseUrl/manga/$mangaId/feed?limit=$limit&offset=$offset'));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        var chapters = data['data'];

        if (chapters.isEmpty) {
          break; // Dừng nếu không còn chương nào
        }

        allChapters.addAll(chapters);
        offset += limit; // Tăng offset để lấy trang tiếp theo
      } else if (response.statusCode == 503) {
        // Nếu gặp lỗi 503 (Bảo trì), ném lỗi với thông báo cụ thể
        throw Exception(
            'Máy chủ MangaDex hiện đang bảo trì, xin vui lòng thử lại sau!');
      } else {
        logError('fetchChapters', response);
        throw Exception('Lỗi khi tải chương. Vui lòng thử lại sau.');
      }
    }

    return allChapters;
  }

  // Lấy ảnh bìa của manga
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

  // Lấy các trang của chương
  Future<List<String>> fetchChapterPages(String chapterId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/at-home/server/$chapterId'));

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      List<String> pages = List<String>.from(data['chapter']['data']);
      String baseUrl = data['baseUrl'];
      String hash = data['chapter']['hash'];
      // Xây dựng URL đầy đủ cho các trang ảnh
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
      return data['data'] ?? []; // Trả về toàn bộ dữ liệu tag, bao gồm id và attributes
    } else {
      logError('fetchTags', response);
      throw Exception('Lỗi khi tải danh sách tags');
    }
  }

  Future<List<dynamic>> advancedSearch({
    required String title,
    required List<String> includedTags,
    required List<String> excludedTags,
    required String safety,
    required String status,
    required String demographic,
    required String sortBy,
  }) async {
    Map<String, dynamic> params = {
      if (title.isNotEmpty) 'title': title,
      if (includedTags.isNotEmpty) 'includedTags[]': includedTags,
      if (excludedTags.isNotEmpty) 'excludedTags[]': excludedTags,
      if (safety != 'Tất cả') 'contentRating[]': [safety.toLowerCase()],
      if (status != 'Tất cả') 'status[]': [status.toLowerCase()],
      if (demographic != 'Tất cả') 'publicationDemographic[]': [demographic.toLowerCase()],
      'order[updatedAt]': sortBy == 'Mới cập nhật' ? 'desc' : 'asc',
    };

    final uri = Uri.parse('$baseUrl/manga').replace(queryParameters: params);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['data'];
    } else {
      logError('advancedSearch', response);
      throw Exception('Lỗi khi thực hiện tìm kiếm nâng cao: ${response.statusCode}');
    }
  }

}
