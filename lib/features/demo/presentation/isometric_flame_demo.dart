import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// アプローチ②: Flame(ゲームエンジン)のComponentツリーに乗せるデモ。
/// タイルをタップするとヒーローがそこへ移動する。奥行きの前後関係は
/// 自前で計算せず、各ComponentのpriorityをFlameに任せているのがポイント。
const double _tileWidth = 64;
const double _tileHeight = 32;
const int _gridSize = 6;

class IsometricFlameDemo extends StatelessWidget {
  const IsometricFlameDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return GameWidget(game: _IsometricFlameGame());
  }
}

class _IsometricFlameGame extends FlameGame {
  late final _Hero hero;

  @override
  Color backgroundColor() => const Color(0xFFEFEBE9);

  @override
  Future<void> onLoad() async {
    // Canvasでベクター描画していた椅子を、assets/images/chair2.pngの
    // 画像アセットに差し替える。奥行き管理(priority = row + col)の
    // 仕組みは絵の作り方が変わっても一切変える必要がない。
    final chairSprite = await Sprite.load('chair2.png');

    final origin = Vector2(size.x / 2, _tileHeight * 2);

    for (var row = 0; row < _gridSize; row++) {
      for (var col = 0; col < _gridSize; col++) {
        add(_Tile(row: row, col: col, origin: origin, onTap: _moveHeroTo));
      }
    }

    hero = _Hero(row: 0, col: 0, origin: origin);
    add(hero);

    add(_Chair(row: 3, col: 2, origin: origin, sprite: chairSprite));
  }

  void _moveHeroTo(int row, int col) => hero.moveTo(row, col);
}

class _Tile extends PositionComponent with TapCallbacks {
  _Tile({
    required this.row,
    required this.col,
    required Vector2 origin,
    required this.onTap,
  }) : super(
         position: Vector2(
           origin.x + (col - row) * _tileWidth / 2,
           origin.y + (col + row) * _tileHeight / 2,
         ),
         size: Vector2(_tileWidth, _tileHeight),
         anchor: Anchor.center,
         priority: row + col,
       );

  final int row;
  final int col;
  final void Function(int row, int col) onTap;

  @override
  void render(Canvas canvas) {
    final color = (row + col).isEven ? const Color(0xFF64B5F6) : const Color(0xFF90CAF9);
    final path = Path()
      ..moveTo(size.x / 2, 0)
      ..lineTo(size.x, size.y / 2)
      ..lineTo(size.x / 2, size.y)
      ..lineTo(0, size.y / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke);
  }

  @override
  void onTapDown(TapDownEvent event) => onTap(row, col);
}

class _Hero extends PositionComponent {
  _Hero({required int row, required int col, required this.origin})
    : _row = row,
      _col = col,
      super(size: Vector2(28, 40), anchor: Anchor.bottomCenter) {
    _updatePosition();
  }

  final Vector2 origin;
  int _row;
  int _col;

  void moveTo(int row, int col) {
    _row = row;
    _col = col;
    _updatePosition();
  }

  void _updatePosition() {
    position = Vector2(
      origin.x + (_col - _row) * _tileWidth / 2,
      origin.y + (_col + _row) * _tileHeight / 2,
    );
    // タイルと同じ優先度計算式にするだけで、Flameが前後関係を都度並べ替えてくれる。
    priority = _row + _col + 1;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawOval(Rect.fromLTWH(0, 26, size.x, 12), Paint()..color = Colors.black26);
    canvas.drawCircle(Offset(size.x / 2, 8), 8, Paint()..color = const Color(0xFFE53935));
    canvas.drawRect(
      Rect.fromLTWH(size.x / 2 - 6, 16, 12, 20),
      Paint()..color = const Color(0xFFE53935),
    );
  }
}

/// 家具の例として置く椅子。assets/images/chair2.png(400x400, 白背景)を
/// 貼るSpriteComponent。位置と優先度の計算式はタイル/ヒーローと完全に同じで、
/// 画像を差し替えるだけなら奥行き管理には一切手を加える必要がない。
class _Chair extends SpriteComponent {
  _Chair({
    required this.row,
    required this.col,
    required Vector2 origin,
    required Sprite sprite,
  }) : super(
         sprite: sprite,
         position: Vector2(
           origin.x + (col - row) * _tileWidth / 2,
           origin.y + (col + row) * _tileHeight / 2,
         ),
         size: Vector2(100, 100),
         anchor: const Anchor(0.5, 0.9),
         priority: row + col,
       );

  final int row;
  final int col;
}
