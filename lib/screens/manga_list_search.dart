import '../services/model.dart';
import 'package:flutter/material.dart';
import '../services/manga_grid_view.dart';

class MangaListSearch extends StatelessWidget {
  final SortManga sortManga;

  const MangaListSearch({
    Key? key,
    required this.sortManga,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kết Quả Tìm Kiếm'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: MangaGridView(sortManga: sortManga),
    );
  }
}
