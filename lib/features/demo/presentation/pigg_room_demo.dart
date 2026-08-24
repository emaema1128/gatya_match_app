import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'furniture_photo_processor.dart';

/// アメーバピグ風の「壁+床」の擬似部屋。タイルグリッドはやめて、
/// 床を台形(奥が狭く手前が広い)として連続座標(xT, depthT)で表現する。
/// depthTが大きい(手前)ほど拡大表示・優先度も高くして、
/// 奥へ行くほど小さく・奥に隠れるという遠近感を出している。
double _lerp(double a, double b, double t) => a + (b - a) * t;

class _RoomLayout {
  _RoomLayout(Vector2 canvasSize)
    : canvasWidth = canvasSize.x,
      canvasHeight = canvasSize.y,
      topY = canvasSize.y * 0.30,
      bottomY = canvasSize.y * 0.95,
      topLeftX = canvasSize.x * 0.24,
      topRightX = canvasSize.x * 0.76,
      bottomLeftX = canvasSize.x * 0.03,
      bottomRightX = canvasSize.x * 0.97;

  final double canvasWidth;
  final double canvasHeight;
  final double topY;
  final double bottomY;
  final double topLeftX;
  final double topRightX;
  final double bottomLeftX;
  final double bottomRightX;

  static const double _minScale = 0.55;
  static const double _maxScale = 1.05;

  Vector2 toScreen(double xT, double depthT) {
    final d = depthT.clamp(0.0, 1.0);
    final leftX = _lerp(topLeftX, bottomLeftX, d);
    final rightX = _lerp(topRightX, bottomRightX, d);
    final y = _lerp(topY, bottomY, d);
    final x = _lerp(leftX, rightX, xT.clamp(0.0, 1.0));
    return Vector2(x, y);
  }

  double scaleAt(double depthT) => _lerp(_minScale, _maxScale, depthT.clamp(0.0, 1.0));

  // ドラッグ中などに使う。範囲外はクランプして部屋の中に留める。
  (double, double) fromScreen(Vector2 pos) {
    final depthT = ((pos.y - topY) / (bottomY - topY)).clamp(0.0, 1.0);
    final leftX = _lerp(topLeftX, bottomLeftX, depthT);
    final rightX = _lerp(topRightX, bottomRightX, depthT);
    final xT = ((pos.x - leftX) / (rightX - leftX)).clamp(0.0, 1.0);
    return (xT, depthT);
  }

  // タップ判定用。床の外(壁など)なら null。
  (double, double)? fromScreenIfInside(Vector2 pos) {
    final depthT = (pos.y - topY) / (bottomY - topY);
    if (depthT < 0 || depthT > 1) return null;
    final leftX = _lerp(topLeftX, bottomLeftX, depthT);
    final rightX = _lerp(topRightX, bottomRightX, depthT);
    final xT = (pos.x - leftX) / (rightX - leftX);
    if (xT < 0 || xT > 1) return null;
    return (xT, depthT);
  }
}

enum WallpaperKind {
  pink('ピンク', Color(0xFFFBE4EC), Color(0xFFF7D3E0)),
  mint('ミント', Color(0xFFE3F6EF), Color(0xFFD3EEE3)),
  lavender('ラベンダー', Color(0xFFEDE7F9), Color(0xFFE0D6F3)),
  sky('スカイ', Color(0xFFE3F1FB), Color(0xFFD3E7F7));

  const WallpaperKind(this.label, this.leftColor, this.rightColor);

  final String label;
  final Color leftColor;
  final Color rightColor;
}

enum FurnitureKind {
  woodChair('chair.png', 80, 100, 0.5, 0.88, '北欧チェア'),
  leatherChair('chair2.png', 100, 100, 0.5, 0.9, 'レザーチェア');

  const FurnitureKind(this.asset, this.width, this.height, this.anchorX, this.anchorY, this.label);

  final String asset;
  final double width;
  final double height;
  final double anchorX;
  final double anchorY;
  final String label;
}

class PiggRoomDemo extends StatefulWidget {
  const PiggRoomDemo({super.key});

  @override
  State<PiggRoomDemo> createState() => _PiggRoomDemoState();
}

class _PiggRoomDemoState extends State<PiggRoomDemo> {
  final _game = _PiggRoomGame();
  FurnitureKind? _selectedKind;
  WallpaperKind _wallpaper = WallpaperKind.pink;

  void _toggleKind(FurnitureKind kind) {
    setState(() {
      _selectedKind = _selectedKind == kind ? null : kind;
      _game.selectedKind = _selectedKind;
    });
  }

  void _selectWallpaper(WallpaperKind kind) {
    setState(() {
      _wallpaper = kind;
      _game.setWallpaper(kind);
    });
  }

  void _clear() => setState(_game.clearFurniture);

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null || !mounted) return;
    final originalBytes = await file.readAsBytes();
    if (!mounted) return;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _ProcessingDialog(),
      ),
    );

    Uint8List processedBytes;
    try {
      processedBytes = await processFurniturePhoto(originalBytes);
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _PhotoPreviewDialog(original: originalBytes, processed: processedBytes),
    );
    if (confirmed != true || !mounted) return;

    final codec = await ui.instantiateImageCodec(processedBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final sprite = Sprite(image);

    const maxDim = 120.0;
    final aspect = image.width / image.height;
    final spriteSize = aspect >= 1
        ? Vector2(maxDim, maxDim / aspect)
        : Vector2(maxDim * aspect, maxDim);

    _game.addPhotoFurniture(sprite, spriteSize);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: GameWidget(game: _game)),
        _Palette(
          selectedFurniture: _selectedKind,
          onSelectFurniture: _toggleKind,
          selectedWallpaper: _wallpaper,
          onSelectWallpaper: _selectWallpaper,
          onClear: _clear,
          onPickPhoto: _pickPhoto,
        ),
      ],
    );
  }
}

class _ProcessingDialog extends StatelessWidget {
  const _ProcessingDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 16),
          Text('背景を消してイラスト風に加工中...'),
        ],
      ),
    );
  }
}

class _PhotoPreviewDialog extends StatelessWidget {
  const _PhotoPreviewDialog({required this.original, required this.processed});

  final Uint8List original;
  final Uint8List processed;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('この家具を部屋に置きますか?'),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(child: _PreviewTile(label: '元の写真', bytes: original)),
          const SizedBox(width: 12),
          Expanded(child: _PreviewTile(label: '加工後', bytes: processed, checkerboard: true)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('部屋に置く'),
        ),
      ],
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.label, required this.bytes, this.checkerboard = false});

  final String label;
  final Uint8List bytes;
  final bool checkerboard;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            color: checkerboard ? const Color(0xFFF0F0F0) : null,
          ),
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ],
    );
  }
}

class _Palette extends StatelessWidget {
  const _Palette({
    required this.selectedFurniture,
    required this.onSelectFurniture,
    required this.selectedWallpaper,
    required this.onSelectWallpaper,
    required this.onClear,
    required this.onPickPhoto,
  });

  final FurnitureKind? selectedFurniture;
  final void Function(FurnitureKind kind) onSelectFurniture;
  final WallpaperKind selectedWallpaper;
  final void Function(WallpaperKind kind) onSelectWallpaper;
  final VoidCallback onClear;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final kind in FurnitureKind.values)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _PaletteItem(
                    kind: kind,
                    selected: selectedFurniture == kind,
                    onTap: () => onSelectFurniture(kind),
                  ),
                ),
              IconButton(
                onPressed: onPickPhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                tooltip: '写真から家具を追加',
              ),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: '部屋をリセット',
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  selectedFurniture == null ? '床タップ→歩く' : '床タップ→設置\n設置済みはドラッグで移動/タップで削除',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('壁紙  ', style: Theme.of(context).textTheme.bodySmall),
              for (final kind in WallpaperKind.values)
                _WallpaperSwatch(
                  kind: kind,
                  selected: selectedWallpaper == kind,
                  onTap: () => onSelectWallpaper(kind),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WallpaperSwatch extends StatelessWidget {
  const _WallpaperSwatch({required this.kind, required this.selected, required this.onTap});

  final WallpaperKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [kind.leftColor, kind.rightColor]),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.black26,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}

class _PaletteItem extends StatelessWidget {
  const _PaletteItem({required this.kind, required this.selected, required this.onTap});

  final FurnitureKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.black12,
            width: selected ? 2 : 1,
          ),
          color: Colors.white,
        ),
        child: Image.asset('assets/images/${kind.asset}', fit: BoxFit.contain),
      ),
    );
  }
}

class _PiggRoomGame extends FlameGame {
  FurnitureKind? selectedKind;

  late final _RoomLayout layout;
  late final _RoomBackground background;
  late final _Avatar avatar;
  final Map<FurnitureKind, Sprite> _sprites = {};
  final List<_Furniture> _placedFurniture = [];

  @override
  Color backgroundColor() => const Color(0xFFFBE4EC);

  @override
  Future<void> onLoad() async {
    for (final kind in FurnitureKind.values) {
      _sprites[kind] = await Sprite.load(kind.asset);
    }

    layout = _RoomLayout(size);

    background = _RoomBackground(layout, WallpaperKind.pink);
    add(background);
    add(_FloorHitArea(layout: layout, onFloorTap: _handleFloorTap, size: size));

    avatar = _Avatar(layout, xT: 0.5, depthT: 0.22);
    add(avatar);
  }

  void setWallpaper(WallpaperKind kind) => background.wallpaper = kind;

  void _handleFloorTap(double xT, double depthT) {
    final kind = selectedKind;
    if (kind == null) {
      avatar.walkTo(xT, depthT);
      return;
    }
    _addFurniture(
      xT: xT,
      depthT: depthT,
      sprite: _sprites[kind]!,
      spriteSize: Vector2(kind.width, kind.height),
      spriteAnchor: Anchor(kind.anchorX, kind.anchorY),
    );
  }

  /// 写真から作った家具を部屋の中央あたりに置く。以降はプリセット家具と
  /// まったく同じにドラッグ/タップで扱える。
  void addPhotoFurniture(Sprite sprite, Vector2 spriteSize) {
    _addFurniture(
      xT: 0.5,
      depthT: 0.45,
      sprite: sprite,
      spriteSize: spriteSize,
      spriteAnchor: const Anchor(0.5, 0.92),
    );
  }

  void _addFurniture({
    required double xT,
    required double depthT,
    required Sprite sprite,
    required Vector2 spriteSize,
    required Anchor spriteAnchor,
  }) {
    final furniture = _Furniture(
      layout: layout,
      game: this,
      xT: xT,
      depthT: depthT,
      sprite: sprite,
      spriteSize: spriteSize,
      spriteAnchor: spriteAnchor,
    );
    _placedFurniture.add(furniture);
    add(furniture);
  }

  void removeFurniture(_Furniture furniture) {
    _placedFurniture.remove(furniture);
    furniture.removeFromParent();
  }

  void clearFurniture() {
    for (final furniture in List.of(_placedFurniture)) {
      furniture.removeFromParent();
    }
    _placedFurniture.clear();
  }
}

class _RoomBackground extends PositionComponent {
  _RoomBackground(this.layout, this.wallpaper)
    : super(priority: -10, size: Vector2(layout.canvasWidth, layout.canvasHeight));

  final _RoomLayout layout;
  WallpaperKind wallpaper;

  @override
  void render(Canvas canvas) {
    final w = layout.canvasWidth;

    // 左右の壁(明暗差で部屋の角を表現)
    canvas.drawRect(Rect.fromLTWH(0, 0, w, layout.topY), Paint()..color = wallpaper.leftColor);
    canvas.drawRect(
      Rect.fromLTWH(w / 2, 0, w / 2, layout.topY),
      Paint()..color = wallpaper.rightColor,
    );

    // 窓
    final windowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.62, layout.topY * 0.18, w * 0.22, layout.topY * 0.5),
      const Radius.circular(10),
    );
    canvas.drawRRect(windowRect, Paint()..color = const Color(0xFFDFF3FF));
    canvas.drawRRect(
      windowRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // 幅木
    canvas.drawRect(
      Rect.fromLTWH(0, layout.topY - 4, w, 6),
      Paint()..color = const Color(0xFFE8B4C8),
    );

    // 床(台形)
    final floor = Path()
      ..moveTo(layout.topLeftX, layout.topY)
      ..lineTo(layout.topRightX, layout.topY)
      ..lineTo(layout.bottomRightX, layout.bottomY)
      ..lineTo(layout.bottomLeftX, layout.bottomY)
      ..close();
    canvas.drawPath(floor, Paint()..color = const Color(0xFFE8C9A0));

    // 奥行きの目安ライン
    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1.5;
    for (final t in [0.25, 0.5, 0.75]) {
      final top = layout.toScreen(t, 0);
      final bottom = layout.toScreen(t, 1);
      canvas.drawLine(Offset(top.x, top.y), Offset(bottom.x, bottom.y), linePaint);
    }

    // ラグ
    final rugCenter = layout.toScreen(0.5, 0.55);
    final rugScale = layout.scaleAt(0.55);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(rugCenter.x, rugCenter.y),
        width: 130 * rugScale,
        height: 60 * rugScale,
      ),
      Paint()..color = const Color(0xFFFFF3D6).withValues(alpha: 0.8),
    );
  }
}

class _FloorHitArea extends PositionComponent with TapCallbacks {
  _FloorHitArea({required this.layout, required this.onFloorTap, required Vector2 size})
    : super(priority: -5, size: size);

  final _RoomLayout layout;
  final void Function(double xT, double depthT) onFloorTap;

  @override
  void onTapDown(TapDownEvent event) {
    final hit = layout.fromScreenIfInside(event.localPosition);
    if (hit != null) onFloorTap(hit.$1, hit.$2);
  }
}

class _Avatar extends PositionComponent {
  _Avatar(this.layout, {required this.xT, required this.depthT})
    : super(anchor: Anchor.bottomCenter, size: Vector2(30, 46)) {
    _syncTransform();
  }

  final _RoomLayout layout;
  double xT;
  double depthT;

  double? _targetXT;
  double? _targetDepthT;
  double _walkCycle = 0;

  void walkTo(double newXT, double newDepthT) {
    _targetXT = newXT;
    _targetDepthT = newDepthT;
  }

  void _syncTransform() {
    position = layout.toScreen(xT, depthT);
    scale = Vector2.all(layout.scaleAt(depthT));
    priority = (depthT * 10000).round();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final targetX = _targetXT;
    final targetD = _targetDepthT;
    if (targetX == null || targetD == null) return;

    const speed = 1.6; // 部屋の幅を1としたときの秒速
    final dx = targetX - xT;
    final dd = targetD - depthT;
    final dist = math.sqrt(dx * dx + dd * dd);
    if (dist < 0.01) {
      xT = targetX;
      depthT = targetD;
      _targetXT = null;
      _targetDepthT = null;
      _walkCycle = 0;
    } else {
      final step = math.min(speed * dt, dist);
      xT += dx / dist * step;
      depthT += dd / dist * step;
      _walkCycle += dt * 10;
    }
    _syncTransform();
  }

  @override
  void render(Canvas canvas) {
    final bob = _targetXT != null ? math.sin(_walkCycle).abs() * 2 : 0.0;
    canvas.drawOval(Rect.fromLTWH(2, size.y - 6, size.x - 4, 8), Paint()..color = Colors.black26);
    canvas.drawCircle(Offset(size.x / 2, 10 - bob), 9, Paint()..color = const Color(0xFFE53935));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.x / 2 - 7, 20 - bob, 14, 22), const Radius.circular(6)),
      Paint()..color = const Color(0xFFE53935),
    );
  }
}

/// 設置済みの家具。ドラッグ中も(xT, depthT)を再計算してスケールを更新するので、
/// 奥へ動かすと縮み、手前へ動かすと拡大される。プリセット(FurnitureKind)由来か
/// 写真から作った家具かを問わず、spriteとsize/anchorさえ渡せば同じように扱える。
class _Furniture extends SpriteComponent with DragCallbacks, TapCallbacks {
  _Furniture({
    required this.layout,
    required this.game,
    required this.xT,
    required this.depthT,
    required Sprite sprite,
    required Vector2 spriteSize,
    required Anchor spriteAnchor,
  }) : super(sprite: sprite, size: spriteSize, anchor: spriteAnchor) {
    _syncTransform();
  }

  final _RoomLayout layout;
  final _PiggRoomGame game;
  double xT;
  double depthT;

  void _syncTransform() {
    position = layout.toScreen(xT, depthT);
    scale = Vector2.all(layout.scaleAt(depthT));
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    priority = 100000; // ドラッグ中は最前面
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    final moved = position + event.localDelta;
    final (nxT, nDepthT) = layout.fromScreen(moved);
    xT = nxT;
    depthT = nDepthT;
    _syncTransform();
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    priority = (depthT * 10000).round();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    priority = (depthT * 10000).round();
  }

  @override
  void onTapUp(TapUpEvent event) => game.removeFurniture(this);
}
