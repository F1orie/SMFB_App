import 'package:flutter/material.dart';

import 'package:smf_app/app/main.dart';


// 作成したページのパスに合わせてインポートしてください
import 'package:smf_app/features/fb/presentation/pages/fb_dashboard_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sleep Analysis App',
      theme: ThemeData(
        brightness: Brightness.dark, // 睡眠アプリなのでダークモードがおすすめ
        primarySwatch: Colors.blue,
      ),
      // ↓ ここを FbDashboardPage に変更することで、起動時に表示されます
      home: const FbDashboardPage(), 
    );
  }
}