import 'manga_detail_screen.dart';
import 'package:flutter/material.dart';
import '../services/manga_dex_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MangaListScreen extends StatefulWidget {
  @override
  _MangaListScreenState createState() => _MangaListScreenState();
}

class _MangaListScreenState extends State<MangaListScreen>
    with AutomaticKeepAliveClientMixin {
  final MangaDexService _service = MangaDexService(); // Dịch vụ để gọi API MangaDex
  final ScrollController _scrollController = ScrollController(); // Điều khiển cuộn danh sách

  List<dynamic> mangas = []; // Danh sách manga tải về
  Map<String, String> coverCache = {}; // Bộ nhớ đệm cho ảnh bìa manga
  int offset = 0; // Vị trí hiện tại trong danh sách manga (phân trang)
  bool isLoading = false; // Trạng thái tải dữ liệu

  int _selectedIndex = 0; // Chỉ số tab hiện tại

  @override
  bool get wantKeepAlive => true; // Giữ trạng thái màn hình khi chuyển tab

  @override
  void initState() {
    super.initState();
    _loadMangas(); // Tải danh sách manga khi khởi tạo màn hình
    _scrollController.addListener(_onScroll); // Gắn sự kiện cuộn
  }

  // Xử lý khi chuyển tab trong BottomNavigationBar
  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Có thể thêm logic khác khi chuyển tab
    });
  }

  // Tải danh sách manga từ API
  Future<void> _loadMangas() async {
    if (isLoading) return; // Tránh tải dữ liệu trùng lặp
    setState(() => isLoading = true); // Bắt đầu tải dữ liệu

    try {
      var newMangas = await _service.fetchMangaList(limit: 21, offset: offset);
      setState(() {
        // Thêm manga mới vào danh sách, đảm bảo không trùng lặp
        for (var manga in newMangas) {
          if (!mangas.any((existingManga) => existingManga['id'] == manga['id'])) {
            mangas.add(manga);
          }
        }
        offset += 21; // Cập nhật offset cho lần tải tiếp theo
      });
    } catch (e) {
      // Kiểm tra lỗi 503
      if (e.toString().contains("503")) {
        _showErrorDialog("Máy chủ Mangadex hiện đang bảo trì, xin vui lòng thử lại sau!");
      } else {
        _showErrorDialog("Lỗi khi tải manga. Vui lòng thử lại sau.");
      }
      print('Lỗi khi tải manga: $e');
    } finally {
      setState(() => isLoading = false); // Kết thúc tải dữ liệu
    }
  }

  // Hiển thị thông báo lỗi cho người dùng
  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Xử lý sự kiện khi cuộn danh sách
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 && // Kiểm tra gần cuối danh sách
        !isLoading) {
      _loadMangas(); // Tải thêm dữ liệu khi đến gần cuối
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: Text('Danh Sách Truyện Tranh')),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang Chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Tìm Kiếm',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Tài Khoản',
          ),
        ],
      ),
    );
  }

  // Xây dựng nội dung theo tab được chọn
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: // Trang Chủ
        return _buildMangaGrid();
      case 1: // Tìm Kiếm
        return Center(child: Text('Chức năng Tìm Kiếm đang được phát triển'));
      case 2: // Tài Khoản
        return Center(child: Text('Chức năng Tài Khoản đang được phát triển'));
      default:
        return _buildMangaGrid();
    }
  }

  // Xây dựng lưới hiển thị danh sách manga
  Widget _buildMangaGrid() {
    if (mangas.isEmpty && isLoading) {
      // Hiển thị vòng tròn chờ khi đang tải dữ liệu lần đầu
      return Center(child: CircularProgressIndicator());
    }

    return GridView.builder(
      controller: _scrollController, // Điều khiển cuộn để tải thêm dữ liệu
      padding: const EdgeInsets.all(8.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 cột trong lưới
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 0.7, // Tỉ lệ chiều cao / chiều rộng của mỗi mục
      ),
      itemCount: mangas.length + (isLoading ? 1 : 0), // Thêm 1 mục để hiển thị loading
      itemBuilder: (context, index) {
        if (index >= mangas.length) {
          // Hiển thị vòng tròn chờ khi tải thêm dữ liệu
          return Center(child: CircularProgressIndicator());
        }

        var manga = mangas[index];
        String mangaId = manga['id'];
        String title = manga['attributes']['title']['en'] ?? 'Không có tiêu đề';

        return GestureDetector(
          onTap: () {
            // Điều hướng đến màn hình chi tiết khi chọn một manga
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MangaDetailScreen(mangaId: mangaId),
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: _buildCoverImage(mangaId),
              ),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  // Xây dựng hình ảnh bìa cho mỗi manga

  Widget _buildCoverImage(String mangaId) {
    // Kiểm tra nếu đã có URL trong bộ nhớ đệm
    if (coverCache.containsKey(mangaId)) {
      return CachedNetworkImage(
        imageUrl: coverCache[mangaId]!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => Icon(Icons.broken_image),
        useOldImageOnUrlChange: true,  // Giữ ảnh cũ khi tải lại
        cacheManager: CacheManager(
          Config(
            'customCacheKey',
            stalePeriod: Duration(days: 0),  // Cache chỉ trong phiên làm việc
            maxNrOfCacheObjects: 231,  // Giới hạn số lượng ảnh lưu trữ
          ),
        ),
      );
    } else {
      // Tải ảnh và lưu URL vào bộ nhớ đệm
      return FutureBuilder<String>(
        future: _service.fetchCoverUrl(mangaId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            coverCache[mangaId] = snapshot.data!;
            return CachedNetworkImage(
              imageUrl: snapshot.data!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => Icon(Icons.broken_image),
              useOldImageOnUrlChange: true,
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      );
    }
  }
}
