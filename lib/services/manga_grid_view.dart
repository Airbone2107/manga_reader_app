import 'package:flutter/material.dart';
import '../services/manga_dex_service.dart';
import '../screens/manga_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MangaGridView extends StatefulWidget {
  //Các tham số phục cho việc Filter
  final String? title;
  final List<String>? includedTags;
  final List<String>? excludedTags;
  final String? safety;
  final String? status;
  final String? demographic;
  final String? sortBy;

  const MangaGridView({
    Key? key,
    this.title,
    this.includedTags,
    this.excludedTags,
    this.safety,
    this.status,
    this.demographic,
    this.sortBy,
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
        //Tham số phân trang
        limit: 21,
        offset: offset,
        // Các tham số filter nếu có
        title: widget.title,
        includedTags: widget.includedTags,
        excludedTags: widget.excludedTags,
        safety: widget.safety,
        status: widget.status,
        demographic: widget.demographic,
        sortBy: widget.sortBy,
      );
      setState(() {
        //Kiểm tra để tránh trùng manga
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
}