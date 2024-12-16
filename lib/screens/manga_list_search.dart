import 'manga_search_screen.dart';
import 'package:flutter/material.dart';
import '../services/manga_grid_view.dart';

class MangaListSearch extends StatefulWidget {
  final String? title;
  final List<String>? includedTags;
  final List<String>? excludedTags;
  final String? safety;
  final String? status;
  final String? demographic;
  final String? sortBy;

  const MangaListSearch({
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
  _MangaListSearchState createState() => _MangaListSearchState();
}

class _MangaListSearchState extends State<MangaListSearch> with AutomaticKeepAliveClientMixin {
  int _selectedIndex = 0;

  @override
  bool get wantKeepAlive => true;

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return MangaGridView(
          title: widget.title,
          includedTags: widget.includedTags,
          excludedTags: widget.excludedTags,
          safety: widget.safety,
          status: widget.status,
          demographic: widget.demographic,
          sortBy: widget.sortBy,
        );
      case 1:
        return AdvancedSearchScreen();
      case 2:
        return Center(child: Text('Chức năng Tài Khoản đang được phát triển'));
      default:
        return MangaGridView();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Kết Quả Tìm Kiếm'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Kết Quả',
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
}
