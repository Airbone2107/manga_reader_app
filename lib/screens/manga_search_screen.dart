import 'manga_list_search.dart';
import 'package:flutter/material.dart';
import '../services/manga_dex_service.dart';
import '../services/model.dart';

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

class AdvancedSearchScreen extends StatefulWidget {
  @override
  _AdvancedSearchScreenState createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  final MangaDexService _service = MangaDexService();
  final TextEditingController _searchController = TextEditingController();

  // Bộ lọc
  Set<String> selectedTags = {};
  Set<String> excludedTags = {};
  String safetyFilter = 'Tất cả';
  String statusFilter = 'Tất cả';
  String demographicFilter = 'Tất cả';
  String sortBy = 'Mới cập nhật';

  // Danh sách các tag
  bool isLoading = false;
  List<TagInfo> availableTags = [];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      var tags = await _service.fetchTags();
      setState(() {
        availableTags = tags.map((tag) => TagInfo(
          id: tag['id'],
          name: tag['attributes']['name']['en'] ?? 'Unknown',
          group: tag['attributes']['group'] ?? 'other',
        )).toList();

        // Sắp xếp tags theo group và tên
        availableTags.sort((a, b) {
          int groupCompare = a.group.compareTo(b.group);
          return groupCompare != 0 ? groupCompare : a.name.compareTo(b.name);
        });
      });
    } catch (e) {
      print('Lỗi khi tải tags: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được danh sách tags. Vui lòng thử lại!')),
      );
    }
  }

  Future<void> _performSearch() async {
    SortManga sortManga = SortManga(
      title: _searchController.text.trim(),
      includedTags: selectedTags.toList(),
      excludedTags: excludedTags.toList(),
      safety: safetyFilter,
      status: statusFilter,
      demographic: demographicFilter,
      sortBy: sortBy,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MangaListSearch(sortManga: sortManga),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tìm Truyện Nâng Cao')),
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Tên truyện',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          ExpansionTile(
            title: Text('Tags'),
            children: _buildTagsList(),
          ),
          _buildComboBox(
            label: 'Độ an toàn',
            items: ['Tất cả', 'safe', 'suggestive', 'erotica', 'pornographic'],
            value: safetyFilter,
            onChanged: (value) => setState(() => safetyFilter = value!),
          ),
          _buildComboBox(
            label: 'Tình trạng',
            items: ['Tất cả', 'ongoing', 'completed', 'hiatus', 'cancelled'],
            value: statusFilter,
            onChanged: (value) => setState(() => statusFilter = value!),
          ),
          _buildComboBox(
            label: 'Dành cho',
            items: ['Tất cả', 'shounen', 'shoujo', 'seinen', 'josei'],
            value: demographicFilter,
            onChanged: (value) => setState(() => demographicFilter = value!),
          ),
          _buildComboBox(
            label: 'Sắp xếp theo',
            items: ['Mới cập nhật', 'Truyện mới', 'Theo dõi nhiều nhất'],
            value: sortBy,
            onChanged: (value) => setState(() => sortBy = value!),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: _performSearch,
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Tìm kiếm'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTagsList() {
    Map<String, List<TagInfo>> groupedTags = {};
    for (var tag in availableTags) {
      groupedTags.putIfAbsent(tag.group, () => []).add(tag);
    }

    return groupedTags.entries.map((entry) {
      return ExpansionTile(
        title: Text(entry.key.toUpperCase()),
        children: entry.value.map((tag) {
          bool isIncluded = selectedTags.contains(tag.id);
          bool isExcluded = excludedTags.contains(tag.id);
          return ListTile(
            title: Text(tag.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isIncluded ? Icons.check_box : Icons.check_box_outline_blank,
                    color: Colors.green,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isExcluded) excludedTags.remove(tag.id);
                      isIncluded
                          ? selectedTags.remove(tag.id)
                          : selectedTags.add(tag.id);
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    isExcluded ? Icons.check_box : Icons.check_box_outline_blank,
                    color: Colors.red,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isIncluded) selectedTags.remove(tag.id);
                      isExcluded
                          ? excludedTags.remove(tag.id)
                          : excludedTags.add(tag.id);
                    });
                  },
                ),
              ],
            ),
          );
        }).toList(),
      );
    }).toList();
  }

  Widget _buildComboBox({
    required String label,
    required List<String> items,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
