import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// ユーザーが選んだ家具の写真を、部屋に置けるような透過PNGへ加工する。
/// ①四隅の色を背景とみなし、外周から連結した背景領域だけをflood fillで
///   透過にする(ML不要のチープな背景除去)。
/// ②透過にならなかった部分を減色(ポスタリゼーション)して、
///   写真そのままより少しイラスト寄りの見た目に近づける。
/// 重い画素処理はcompute()で別Isolateへ逃がし、dart:uiが必要な
/// デコード/エンコードだけをメインIsolateで行う。
Future<Uint8List> processFurniturePhoto(Uint8List inputBytes, {int targetWidth = 400}) async {
  final codec = await ui.instantiateImageCodec(inputBytes, targetWidth: targetWidth);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final pixels = Uint8List.fromList(byteData!.buffer.asUint8List());
  final width = image.width;
  final height = image.height;

  final processed = await compute(_cutoutAndStylize, _PixelJob(pixels, width, height));

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(processed, width, height, ui.PixelFormat.rgba8888, completer.complete);
  final outImage = await completer.future;
  final pngData = await outImage.toByteData(format: ui.ImageByteFormat.png);
  return pngData!.buffer.asUint8List();
}

class _PixelJob {
  _PixelJob(this.pixels, this.width, this.height);
  final Uint8List pixels;
  final int width;
  final int height;
}

Uint8List _cutoutAndStylize(_PixelJob job) {
  final w = job.width;
  final h = job.height;
  final px = job.pixels;

  double distToBg(int i, int bgR, int bgG, int bgB) {
    final dr = px[i] - bgR;
    final dg = px[i + 1] - bgG;
    final db = px[i + 2] - bgB;
    return math.sqrt((dr * dr + dg * dg + db * db).toDouble());
  }

  // 四隅の平均色を背景色とみなす。
  const corners = [(0, 0), (-1, 0), (0, -1), (-1, -1)];
  var sumR = 0, sumG = 0, sumB = 0;
  for (final (cx, cy) in corners) {
    final x = cx < 0 ? w - 1 : cx;
    final y = cy < 0 ? h - 1 : cy;
    final i = (y * w + x) * 4;
    sumR += px[i];
    sumG += px[i + 1];
    sumB += px[i + 2];
  }
  final bgR = sumR ~/ corners.length;
  final bgG = sumG ~/ corners.length;
  final bgB = sumB ~/ corners.length;

  const threshold = 36.0;
  const feather = 28.0;

  // 外周から連結した「背景色に近い領域」だけをflood fillで透過にする。
  // 被写体の内部に似た色があっても、外周とつながっていなければ透過にならない。
  final visited = Uint8List(w * h);
  final queue = Queue<int>();

  void trySeed(int x, int y) {
    if (x < 0 || x >= w || y < 0 || y >= h) return;
    final idx = y * w + x;
    if (visited[idx] != 0) return;
    if (distToBg(idx * 4, bgR, bgG, bgB) >= threshold + feather) return;
    visited[idx] = 1;
    queue.add(idx);
  }

  for (var x = 0; x < w; x++) {
    trySeed(x, 0);
    trySeed(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    trySeed(0, y);
    trySeed(w - 1, y);
  }

  while (queue.isNotEmpty) {
    final idx = queue.removeFirst();
    final x = idx % w;
    final y = idx ~/ w;
    final i = idx * 4;
    final dist = distToBg(i, bgR, bgG, bgB);
    // しきい値ちょうどでは硬い輪郭になるので、なだらかにアルファを落とす。
    final alphaFactor = ((dist - threshold) / feather).clamp(0.0, 1.0);
    px[i + 3] = (px[i + 3] * alphaFactor).round().clamp(0, 255);

    trySeed(x + 1, y);
    trySeed(x - 1, y);
    trySeed(x, y + 1);
    trySeed(x, y - 1);
  }

  // 減色の前に軽くぼかしてノイズを均す。写真の微妙な色ムラをそのまま
  // 減色すると、意図しない色ブロックのノイズが出てしまうため。
  // 透明な(背景の)近傍は平均に混ぜない。
  final blurred = Uint8List.fromList(px);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      if (px[i + 3] == 0) continue;
      var rSum = 0, gSum = 0, bSum = 0, count = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
          final ni = (ny * w + nx) * 4;
          if (px[ni + 3] == 0) continue;
          rSum += px[ni];
          gSum += px[ni + 1];
          bSum += px[ni + 2];
          count++;
        }
      }
      blurred[i] = (rSum / count).round();
      blurred[i + 1] = (gSum / count).round();
      blurred[i + 2] = (bSum / count).round();
    }
  }

  // 彩度を少し上げてから減色(ポスタリゼーション)し、イラスト風の平坦な色面に寄せる。
  const levels = 5;
  const saturationBoost = 1.25;
  for (var i = 0; i < px.length; i += 4) {
    if (px[i + 3] == 0) continue;
    final r = blurred[i], g = blurred[i + 1], b = blurred[i + 2];
    final luma = 0.299 * r + 0.587 * g + 0.114 * b;
    for (var c = 0; c < 3; c++) {
      final v = c == 0 ? r : (c == 1 ? g : b);
      final saturated = (luma + (v - luma) * saturationBoost).clamp(0, 255);
      final q = ((saturated / 255 * (levels - 1)).round() / (levels - 1) * 255).round();
      px[i + c] = q.clamp(0, 255);
    }
  }

  return px;
}
