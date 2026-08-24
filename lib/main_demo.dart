import 'package:flutter/material.dart';

import 'features/demo/presentation/isometric_demo_shell_screen.dart';

/// 2.5D/疑似3Dのサンプルだけを単独で見るためのエントリポイント。
/// 既存アプリのルーティングや認証フローには一切触れない。
/// 実行: flutter run -t lib/main_demo.dart
void main() => runApp(const _DemoApp());

class _DemoApp extends StatelessWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '2.5D Demo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const IsometricDemoShellScreen(),
    );
  }
}
