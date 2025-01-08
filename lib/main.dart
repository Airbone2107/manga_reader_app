import 'package:flutter/material.dart';
import 'screens/main/manga_main_screen.dart';

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
      initialRoute: '/', // Route mặc định
      routes: {
        '/': (context) => MangaMainScreen(), // Trang chủ
        '/home': (context) => MangaMainScreen(), // Khai báo route cho nút "home"
      },
    );
  }
}
