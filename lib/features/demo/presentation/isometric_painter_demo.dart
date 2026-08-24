import 'package:flutter/material.dart';

/// アプローチ①: CustomPainterで等角投影を自前計算するデモ。
/// タイルをタップすると高さが 0→1→2→0 と変化し、
/// 奥から手前へ (row+col) 順に描画することで depth sort を手動で行っている。
class IsometricPainterDemo extends StatefulWidget {
  const IsometricPainterDemo({super.key});

  @override
  State<IsometricPainterDemo> createState() => _IsometricPainterDemoState();
}

class _IsometricPainterDemoState extends State<IsometricPainterDemo> {
  static const int gridSize = 6;
  static const double tileWidth = 64;
  static const double tileHeight = 32;
  static const double heightUnit = 22;

  final Map<int, int> _heights = {};

  int _keyOf(int row, int col) => row * gridSize + col;
  int _heightAt(int row, int col) => _heights[_keyOf(row, col)] ?? 0;

  void _handleTap(Offset localPosition, Size size) {
    final origin = Offset(size.width / 2, tileHeight);

    // 手前(row+colが大きい)のタイルから順にヒットテストする。
    final tiles = <(int, int)>[
      for (int row = 0; row < gridSize; row++)
        for (int col = 0; col < gridSize; col++) (row, col),
    ]..sort((a, b) => (b.$1 + b.$2).compareTo(a.$1 + a.$2));

    for (final (row, col) in tiles) {
      final height = _heightAt(row, col);
      final center = origin +
          Offset(
            (col - row) * tileWidth / 2,
            (col + row) * tileHeight / 2 - height * heightUnit,
          );
      final dx = (localPosition.dx - center.dx).abs() / (tileWidth / 2);
      final dy = (localPosition.dy - center.dy).abs() / (tileHeight / 2);
      if (dx + dy <= 1.0) {
        setState(() => _heights[_keyOf(row, col)] = (height + 1) % 3);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapUp: (details) => _handleTap(details.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _IsometricPainter(heights: _heights, gridSize: gridSize),
          ),
        );
      },
    );
  }
}

class _IsometricPainter extends CustomPainter {
  _IsometricPainter({required this.heights, required this.gridSize});

  final Map<int, int> heights;
  final int gridSize;

  static const double tileWidth = 64;
  static const double tileHeight = 32;
  static const double heightUnit = 22;

  int _heightAt(int row, int col) => heights[row * gridSize + col] ?? 0;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, tileHeight);

    // 奥(row+colが小さい)から手前へ描画するpainter's algorithm。
    final order = <(int, int)>[
      for (int row = 0; row < gridSize; row++)
        for (int col = 0; col < gridSize; col++) (row, col),
    ]..sort((a, b) => (a.$1 + a.$2).compareTo(b.$1 + b.$2));

    for (final (row, col) in order) {
      final height = _heightAt(row, col);
      final base = origin +
          Offset((col - row) * tileWidth / 2, (col + row) * tileHeight / 2);
      final isEven = (row + col).isEven;
      final baseColor = isEven ? const Color(0xFF8D6E63) : const Color(0xFFA1887F);

      if (height > 0) _drawTileSides(canvas, base, height, baseColor);
      _drawTileTop(canvas, base, height, baseColor);
    }
  }

  void _drawTileTop(Canvas canvas, Offset base, int height, Color color) {
    final top = base - Offset(0, height * heightUnit);
    final path = Path()
      ..moveTo(top.dx, top.dy - tileHeight / 2)
      ..lineTo(top.dx + tileWidth / 2, top.dy)
      ..lineTo(top.dx, top.dy + tileHeight / 2)
      ..lineTo(top.dx - tileWidth / 2, top.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawTileSides(Canvas canvas, Offset base, int height, Color color) {
    final topY = base.dy - height * heightUnit;
    final leftTop = Offset(base.dx - tileWidth / 2, topY);
    final bottomCenter = Offset(base.dx, topY + tileHeight / 2);
    final rightTop = Offset(base.dx + tileWidth / 2, topY);
    final drop = Offset(0, height * heightUnit);

    final leftFace = Path()
      ..moveTo(leftTop.dx, leftTop.dy)
      ..lineTo(bottomCenter.dx, bottomCenter.dy)
      ..lineTo(bottomCenter.dx, bottomCenter.dy + drop.dy)
      ..lineTo(leftTop.dx, leftTop.dy + drop.dy)
      ..close();
    canvas.drawPath(leftFace, Paint()..color = Color.lerp(Colors.black, color, 0.6)!);

    final rightFace = Path()
      ..moveTo(rightTop.dx, rightTop.dy)
      ..lineTo(bottomCenter.dx, bottomCenter.dy)
      ..lineTo(bottomCenter.dx, bottomCenter.dy + drop.dy)
      ..lineTo(rightTop.dx, rightTop.dy + drop.dy)
      ..close();
    canvas.drawPath(rightFace, Paint()..color = Color.lerp(Colors.black, color, 0.8)!);
  }

  @override
  bool shouldRepaint(covariant _IsometricPainter oldDelegate) => true;
}
