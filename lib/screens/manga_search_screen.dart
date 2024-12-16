import 'manga_list_search.dart';
import 'package:flutter/material.dart';
import '../services/manga_dex_service.dart';

class TagInfo {
  final String id;
  final String name;

  TagInfo({required this.id, required this.name});
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
  Set<String> selectedTagIds = {};
  Set<String> excludedTagIds = {};
  List<TagInfo> availableTags = [];
  List<dynamic> filteredMangas = [];

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
            name: tag['attributes']['name']['en'] ?? 'Unknown'
        )).toList();

        // Sắp xếp tags theo tên
        availableTags.sort((a, b) => a.name.compareTo(b.name));
      });
    } catch (e) {
      print('Lỗi khi tải tags: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được danh sách tags. Vui lòng thử lại!')),
      );
    }
  }

  Future<void> _performSearch() async {
    setState(() => isLoading = true);

    try {
      // Chuyển đến MangaGridView với các tham số filter
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MangaListSearch(
            title: _searchController.text.trim(),
            includedTags: selectedTagIds.toList(),
            excludedTags: excludedTagIds.toList(),
            safety: safetyFilter,
            status: statusFilter,
            demographic: demographicFilter,
            sortBy: sortBy,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Có lỗi xảy ra. Vui lòng thử lại!')),
      );
    } finally {
      setState(() => isLoading = false);
    }
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
          SizedBox(height: 16),
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
          SizedBox(height: 16),
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
    return availableTags.map((tag) {
      bool isIncluded = selectedTagIds.contains(tag.id);
      bool isExcluded = excludedTagIds.contains(tag.id);
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
                  if (isExcluded) excludedTagIds.remove(tag.id);
                  if (isIncluded) {
                    selectedTagIds.remove(tag.id);
                  } else {
                    selectedTagIds.add(tag.id);
                  }
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
                  if (isIncluded) selectedTagIds.remove(tag.id);
                  if (isExcluded) {
                    excludedTagIds.remove(tag.id);
                  } else {
                    excludedTagIds.add(tag.id);
                  }
                });
              },
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(
          horizontal: 16.0, vertical: 8.0), // Tăng padding
      child: Container(
        margin: EdgeInsets.only(bottom: 16.0), // Thêm margin bottom
        child: DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(
                horizontal: 12, vertical: 16), // Thêm padding bên trong
          ),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
