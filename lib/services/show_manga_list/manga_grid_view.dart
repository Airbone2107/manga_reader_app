import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../model.dart';
import '../manga_dex_service.dart';
import '../../screens/detail_manga/manga_detail_screen.dart';

class MangaGridView extends StatefulWidget {
  final SortManga? sortManga;

  const MangaGridView({
    Key? key,
    this.sortManga,
  }) : super(key: key);

  @override
  _MangaGridViewState createState() => _MangaGridViewState();
}

class _MangaGridViewState extends State<MangaGridView> {
  final MangaDexService _service = MangaDexService();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> mangas = [];
  Map<String, String> coverCache = {};
  int offset = 0;
  bool isLoading = false;
  bool isGridView = true; // Add this variable to track view mode

  @override
  void initState() {
    super.initState();
    _loadMangas();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadMangas() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    try {
      var newMangas = await _service.fetchManga(
        limit: 21,
        offset: offset,
        sortManga: widget.sortManga,
      );
      setState(() {
        for (var manga in newMangas) {
          if (!mangas.any((existingManga) => existingManga['id'] == manga['id'])) {
            mangas.add(manga);
          }
        }
        offset += 21;
      });
    } catch (e) {
      if (e.toString().contains("503")) {
        _showErrorMessage("Máy chủ Mangadex hiện đang bảo trì, xin vui lòng thử lại sau!");
      } else {
        _showErrorMessage("Lỗi khi tải manga. Vui lòng thử lại sau.");
      }
      print('Lỗi khi tải manga: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !isLoading) {
      _loadMangas();
    }
  }

  Widget _buildCoverImage(String mangaId) {
    if (coverCache.containsKey(mangaId)) {
      return CachedNetworkImage(
        imageUrl: coverCache[mangaId]!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => Icon(Icons.broken_image),
        useOldImageOnUrlChange: true,
        cacheManager: CacheManager(
          Config(
            'customCacheKey',
            stalePeriod: Duration(days: 0),
            maxNrOfCacheObjects: 231,
          ),
        ),
      );
    }

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
        }
        return Center(child: CircularProgressIndicator());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (mangas.isEmpty && isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Nút chuyển đổi giữa GridView và ListView
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(isGridView ? Icons.list : Icons.grid_view),
                onPressed: () {
                  setState(() {
                    isGridView = !isGridView;
                  });
                },
              ),
            ],
          ),
        ),
        // Nội dung hiển thị
        Expanded(
          child: isGridView ? _buildGridView() : _buildListView(),
        ),
      ],
    );
  }

// Hàm xây dựng giao diện GridView
  Widget _buildGridView() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 0.7,
      ),
      itemCount: mangas.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= mangas.length) {
          return Center(child: CircularProgressIndicator());
        }

        var manga = mangas[index];
        String mangaId = manga['id'];
        String title = manga['attributes']['title']['en'] ?? 'Không có tiêu đề';

        return GestureDetector(
          onTap: () {
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

// Hàm xây dựng giao diện ListView
  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: mangas.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= mangas.length) {
          return Center(child: CircularProgressIndicator());
        }

        var manga = mangas[index];
        String mangaId = manga['id'];
        String title = manga['attributes']['title']['en'] ?? 'Không có tiêu đề';
        String description = manga['attributes']['description']['en'] ?? 'No description available';
        List<String> tags = (manga['attributes']['tags'] ?? [])
            .where((tag) => tag['attributes']?['name']?['en'] is String)
            .map<String>((tag) => tag['attributes']['name']['en'] as String)
            .toList();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MangaDetailScreen(mangaId: mangaId),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12.0),
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 6.0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center, // Căn giữa ảnh theo chiều dọc
              children: [
                // Ảnh bìa manga
                Container(
                  width: 80,
                  height: 120,
                  alignment: Alignment.center, // Căn giữa ảnh bên trong
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: _buildCoverImage(mangaId),
                  ),
                ),
                SizedBox(width: 16),
                // Thông tin manga
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tiêu đề
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      SizedBox(height: 8),
                      // Mô tả
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                      ),
                      SizedBox(height: 8),
                      // Tags
                      Wrap(
                        spacing: 4.0,
                        runSpacing: 4.0,
                        children: tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}