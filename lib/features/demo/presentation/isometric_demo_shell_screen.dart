import 'package:flutter/material.dart';

import 'isometric_flame_demo.dart';
import 'isometric_painter_demo.dart';
import 'pigg_room_demo.dart';
import 'pseudo3d_tilt_demo.dart';

/// 2.5D実装アプローチをタブで見比べるためのデモ画面。
class IsometricDemoShellScreen extends StatelessWidget {
  const IsometricDemoShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('2.5D / 疑似3D デモ'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '① CustomPainter'),
              Tab(text: '② Flame'),
              Tab(text: '③ Transform.matrix'),
              Tab(text: '④ Piggの部屋'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DemoTab(
              description: 'タイルをタップすると高さが変わる。奥行きの前後関係(painter\'s algorithm)は自前実装。',
              child: IsometricPainterDemo(),
            ),
            _DemoTab(
              description: 'タイルをタップするとヒーローが移動する。奥行きの前後関係はFlameのpriorityに任せている。',
              child: IsometricFlameDemo(),
            ),
            _DemoTab(
              description: 'カードをドラッグすると傾く。Widget単体に立体感を出す用途向け。',
              child: Pseudo3dTiltDemo(),
            ),
            _DemoTab(
              description:
                  'アメーバピグ風の擬似部屋。タイルグリッドはなく、床は台形の連続座標。奥へ行くほど小さく、手前ほど大きく表示される。',
              child: PiggRoomDemo(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoTab extends StatelessWidget {
  const _DemoTab({required this.description, required this.child});

  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
