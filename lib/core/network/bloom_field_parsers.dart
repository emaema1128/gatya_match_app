// TODO: bloomの画像配信ベースURLは`https://bloom-developer.com/` + 保存パスと推測
// しているが未検証(実際に写真をアップロードして表示確認するまでは仮定)。
const kBloomBaseUrl = 'https://bloom-developer.com/';

/// bloomのAPIレスポンス(getUserData/getMatchList等)は行の値をstringifyして
/// 返すため、`system_id`のようなint項目もJSON数値/数値文字列のどちらでも
/// 届きうる。
int asBloomInt(Object? value) => value is int ? value : int.parse(value.toString());

/// bloomの`age_id`/`income_id`/`address_id`等は、未選択が`null`または`'0'`
/// として返る。
String? nullableBloomId(Object? value) {
  if (value == null) return null;
  final str = value.toString();
  return (str.isEmpty || str == '0') ? null : str;
}

/// bloomが返すファイルの相対パス(画像スロット`img1_path`、チャットの
/// `img_path`/`audio_path`等)を、表示・再生用の絶対URLへ変換する。
String? resolveBloomAssetUrl(Object? path) {
  final str = path as String?;
  if (str == null || str.isEmpty) return null;
  return '$kBloomBaseUrl$str';
}
