// lib/features/search/view/manga_search_screen.dart
import 'package:flutter/material.dart';
import '../logic/search_logic.dart';

class AdvancedSearchScreen extends StatefulWidget {
  @override
  _AdvancedSearchScreenState createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  final SearchLogic _logic = SearchLogic();

  @override
  void initState() {
    super.initState();
    _logic.init(context, () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _logic.dispose();
    super.dispose();
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
              controller: _logic.searchController,
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
            value: _logic.safetyFilter,
            onChanged: (value) => setState(() => _logic.safetyFilter = value!),
          ),
          _buildComboBox(
            label: 'Tình trạng',
            items: ['Tất cả', 'ongoing', 'completed', 'hiatus', 'cancelled'],
            value: _logic.statusFilter,
            onChanged: (value) => setState(() => _logic.statusFilter = value!),
          ),
          _buildComboBox(
            label: 'Dành cho',
            items: ['Tất cả', 'shounen', 'shoujo', 'seinen', 'josei'],
            value: _logic.demographicFilter,
            onChanged: (value) =>
                setState(() => _logic.demographicFilter = value!),
          ),
          _buildComboBox(
            label: 'Sắp xếp theo',
            items: ['Mới cập nhật', 'Truyện mới', 'Theo dõi nhiều nhất'],
            value: _logic.sortBy,
            onChanged: (value) => setState(() => _logic.sortBy = value!),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: _logic.performSearch,
              child: _logic.isLoading
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
    for (var tag in _logic.availableTags) {
      groupedTags.putIfAbsent(tag.group, () => []).add(tag);
    }

    return groupedTags.entries.map((entry) {
      return ExpansionTile(
        title: Text(entry.key.toUpperCase()),
        children: entry.value.map((tag) {
          bool isIncluded = _logic.selectedTags.contains(tag.id);
          bool isExcluded = _logic.excludedTags.contains(tag.id);
          return ListTile(
            title: Text(tag.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isIncluded
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: Colors.green,
                  ),
                  onPressed: () => _logic.onTagIncludePressed(tag),
                ),
                IconButton(
                  icon: Icon(
                    isExcluded
                        ? Icons.indeterminate_check_box
                        : Icons.check_box_outline_blank,
                    color: Colors.red,
                  ),
                  onPressed: () => _logic.onTagExcludePressed(tag),
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
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
