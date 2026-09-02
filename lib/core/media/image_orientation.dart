import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// EXIFのOrientationタグが示す向きを実際のピクセルデータへ焼き込み、
/// 向き情報に依存しないJPEGバイト列を返す。
///
/// スマホで撮った写真の多くは、実際のピクセルはセンサー向き(横向き)のまま
/// 保存され、「表示するときにどちらへ回転すればよいか」という向き情報
/// (EXIFのOrientationタグ)が別途埋め込まれている。アップロード先が
/// このタグを尊重して回転してくれる保証はないため、送信前にクライアント側で
/// 回転をピクセルへ焼き込んでおく。
///
/// デコードできない場合は元のバイト列をそのまま返す(安全側に倒す)。
Uint8List normalizeJpegOrientation(Uint8List bytes, {int quality = 85}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final oriented = img.bakeOrientation(decoded);
  return Uint8List.fromList(img.encodeJpg(oriented, quality: quality));
}
