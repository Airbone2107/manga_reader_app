import '../../../data/models/sort_manga_model.dart';
import 'package:flutter/material.dart';
import '../../../shared_widgets/manga_grid_view.dart';
import '../../../shared_widgets/scaffold_with_animated_app_bar.dart';

class MangaListSearch extends StatefulWidget {
  final SortManga sortManga;

  const MangaListSearch({
    Key? key,
    required this.sortManga,
  }) : super(key: key);

  @override
  State<MangaListSearch> createState() => _MangaListSearchState();
}

class _MangaListSearchState extends State<MangaListSearch> {
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    return ScaffoldWithAnimatedAppBar(
      title: 'Kết Quả Tìm Kiếm',
      actions: [
        IconButton(
          icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
          },
        ),
      ],
      bodyBuilder: (controller) => MangaGridView(
        sortManga: widget.sortManga,
        controller: controller,
        isGridView: _isGridView,
      ),
    );
  }
}
