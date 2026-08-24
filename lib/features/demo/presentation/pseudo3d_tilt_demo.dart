import 'package:flutter/material.dart';

/// アプローチ③: Transform.matrix + パースペクティブ項によるWidget単位の疑似3D。
/// ドラッグ量に応じてカードをX/Y軸方向に傾け、ガチャ演出のチルトカードのような
/// 見た目を作る。等角マップのような複数オブジェクトの奥行き管理はできないが、
/// 依存ゼロで1つのWidgetに立体感を出すには手軽。
class Pseudo3dTiltDemo extends StatefulWidget {
  const Pseudo3dTiltDemo({super.key});

  @override
  State<Pseudo3dTiltDemo> createState() => _Pseudo3dTiltDemoState();
}

class _Pseudo3dTiltDemoState extends State<Pseudo3dTiltDemo> {
  Offset _drag = Offset.zero;
  static const double _maxTiltRadians = 0.5;

  void _updateDrag(Offset delta, Size cardSize) {
    setState(() {
      final dx = (_drag.dx + delta.dx / cardSize.width).clamp(-1.0, 1.0);
      final dy = (_drag.dy + delta.dy / cardSize.height).clamp(-1.0, 1.0);
      _drag = Offset(dx, dy);
    });
  }

  void _reset() => setState(() => _drag = Offset.zero);

  @override
  Widget build(BuildContext context) {
    const cardSize = Size(220, 300);
    final tiltX = _drag.dy * _maxTiltRadians; // 上下ドラッグ→X軸回転
    final tiltY = -_drag.dx * _maxTiltRadians; // 左右ドラッグ→Y軸回転

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0015) // パースペクティブ項(値が小さいほど強い遠近感)
      ..rotateX(tiltX)
      ..rotateY(tiltY);

    return Center(
      child: GestureDetector(
        onPanUpdate: (details) => _updateDrag(details.delta, cardSize),
        onPanEnd: (_) => _reset(),
        child: Transform(
          alignment: Alignment.center,
          transform: matrix,
          child: _GachaCapsule(size: cardSize, glow: _drag.distance),
        ),
      ),
    );
  }
}

class _GachaCapsule extends StatelessWidget {
  const _GachaCapsule({required this.size, required this.glow});

  final Size size;
  final double glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD54F), Color(0xFFFF7043)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.4 + glow * 0.3),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 64, color: Colors.white),
          SizedBox(height: 12),
          Text(
            'ドラッグして傾けてみて',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
