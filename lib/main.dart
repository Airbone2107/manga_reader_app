import 'package:flutter/material.dart';
import 'screens/manga_list_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manga Reader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MangaListScreen(),
    );
  }
}
