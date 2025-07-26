// lib/features/search/logic/search_logic.dart
import 'package:flutter/material.dart';
import '../../../data/services/mangadex_api_service.dart';
import '../view/manga_list_search.dart';
import '../../../data/models/sort_manga_model.dart';

class TagInfo {
  final String id;
  final String name;
  final String group;

  TagInfo({
    required this.id,
    required this.name,
    required this.group,
  });
}

class SearchLogic {
  final MangaDexApiService _service = MangaDexApiService();
  final TextEditingController searchController = TextEditingController();

  Set<String> selectedTags = {};
  Set<String> excludedTags = {};
  String safetyFilter = 'Tất cả';
  String statusFilter = 'Tất cả';
  String demographicFilter = 'Tất cả';
  String sortBy = 'Mới cập nhật';

  bool isLoading = false;
  List<TagInfo> availableTags = [];

  late BuildContext context;
  late VoidCallback refreshUI;

  void init(BuildContext context, VoidCallback refreshUI) {
    this.context = context;
    this.refreshUI = refreshUI;
    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      var tags = await _service.fetchTags();
      availableTags = tags
          .map((tag) => TagInfo(
                id: tag['id'],
                name: tag['attributes']['name']['en'] ?? 'Unknown',
                group: tag['attributes']['group'] ?? 'other',
              ))
          .toList();

      availableTags.sort((a, b) {
        int groupCompare = a.group.compareTo(b.group);
        return groupCompare != 0 ? groupCompare : a.name.compareTo(b.name);
      });
      refreshUI();
    } catch (e) {
      print('Lỗi khi tải tags: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Không tải được danh sách tags. Vui lòng thử lại!')),
      );
    }
  }

  void onTagIncludePressed(TagInfo tag) {
    if (excludedTags.contains(tag.id)) excludedTags.remove(tag.id);
    selectedTags.contains(tag.id)
        ? selectedTags.remove(tag.id)
        : selectedTags.add(tag.id);
    refreshUI();
  }

  void onTagExcludePressed(TagInfo tag) {
    if (selectedTags.contains(tag.id)) selectedTags.remove(tag.id);
    excludedTags.contains(tag.id)
        ? excludedTags.remove(tag.id)
        : excludedTags.add(tag.id);
    refreshUI();
  }

  Future<void> performSearch() async {
    isLoading = true;
    refreshUI();

    SortManga sortManga = SortManga(
      title: searchController.text.trim(),
      includedTags: selectedTags.toList(),
      excludedTags: excludedTags.toList(),
      safety: safetyFilter,
      status: statusFilter,
      demographic: demographicFilter,
      sortBy: sortBy,
    );

    isLoading = false;
    refreshUI();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MangaListSearch(sortManga: sortManga),
      ),
    );
  }

  void dispose() {
    searchController.dispose();
  }
}
