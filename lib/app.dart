// lib/app.dart
import 'package:flutter/material.dart';
import 'features/main_navigation/view/main_navigation_screen.dart';

class MangaReaderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manga Reader',
      theme: ThemeData(
        // Trở về theme sáng mặc định, chỉ giữ lại màu chủ đạo
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        // Đặt MainNavigationScreen làm màn hình chính
        '/': (context) => MainNavigationScreen(),
      },
    );
  }
}
