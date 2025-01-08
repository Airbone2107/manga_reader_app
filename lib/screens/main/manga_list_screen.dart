import 'package:flutter/material.dart';
import '../../services/model.dart';
import '../../services/manga_grid_view.dart';

class MangaListScreen extends StatefulWidget {
  @override
  _MangaListScreenState createState() => _MangaListScreenState();
}

class _MangaListScreenState extends State<MangaListScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    MangaGridView(
      sortManga: SortManga(
        languages: ['en', 'vn'],
      ),
    ),
    Center(child: Text('Search Screen (Placeholder)')), // Placeholder for Search
    Center(child: Text('Account Screen (Placeholder)')), // Placeholder for Account
  ];

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        items: const [
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
