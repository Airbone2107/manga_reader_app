// lib/features/home/view/home_screen.dart
import 'package:flutter/material.dart';
import '../../../data/models/sort_manga_model.dart';
import '../../../shared_widgets/manga_grid_view.dart';
import '../../../shared_widgets/scaffold_with_animated_app_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    return ScaffoldWithAnimatedAppBar(
      title: 'Manga Reader',
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
        sortManga: SortManga(
          languages: ['en', 'vi'],
        ),
        controller: controller,
        isGridView: _isGridView,
      ),
    );
  }
}
