import '../../services/model.dart';
import '../account/account_screen.dart';
import '../search/manga_search_screen.dart';
import 'package:flutter/material.dart';
import '../../services/manga_grid_view.dart';

class MangaMainScreen extends StatefulWidget {
  @override
  _MangaMainScreenState createState() => _MangaMainScreenState();
}

class _MangaMainScreenState extends State<MangaMainScreen> with AutomaticKeepAliveClientMixin {
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
          sortManga: SortManga(
            languages: ['en', 'vn'],
          ),
        );
      case 1:
        return AdvancedSearchScreen();
      case 2:
        return AccountScreen();
      default:
        return MangaGridView(
          sortManga: SortManga(
            languages: ['en', 'vn'],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
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
}
