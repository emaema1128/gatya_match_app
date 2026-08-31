import '../../../core/auth/sex.dart';
import '../../../core/network/bloom_field_parsers.dart';

/// `getMatchList`/`spinGacha`/`getReceivedLikeList`の1件分——
/// お相手のプロフィール表示用データ。
///
/// bloomの`Matches::getMatchList`は`SELECT m.*, u.*, ca.alias ...`で
/// 行を返す。`m`(matches)と`u`(user)は両方`system_id`列を持ち、後から
/// SELECTされた`u.system_id`(=相手のsystem_id)が連想配列のキーを上書き
/// するため、この`system_id`は常に相手側の値になる。
///
/// [gacha-redesign/issues/03](../../../../.scratch/gacha-redesign/issues/03-other-profile-view-data-research.md)
/// の調査により、一覧系API(`getMatchList`/`spinGacha`等)は元々`SELECT u.*`で
/// userテーブルの全カラムを返しており、`income_id`・`img2`・`img3`も既に
/// レスポンスに含まれていると判明——抜粋カードでもプロフィール詳細でも
/// このモデルをそのまま使い回せる。
class MatchData {
  const MatchData({
    required this.systemId,
    required this.username,
    required this.sex,
    required this.ageId,
    required this.addressId,
    required this.incomeId,
    required this.comment,
    required this.photoUrls,
    this.isRecycled = false,
  });

  final int systemId;
  final String username;
  final Sex sex;
  final String? ageId;
  final String? addressId;
  final String? incomeId;
  final String comment;

  /// インデックス0/1/2がbloomのimg1/img2/img3スロットに対応。空スロットはnull。
  final List<String?> photoUrls;

  /// ガチャの「以前見たお相手」再表示枠だったかどうか(stage3-gacha-home参照)。
  /// マッチ一覧等では常にfalse。
  final bool isRecycled;

  /// 抜粋カード(1枚だけ表示すればよい場面)向けの簡易アクセサ。
  String? get photoUrl => photoUrls.isNotEmpty ? photoUrls[0] : null;

  factory MatchData.fromMatchListEntry(Map<String, dynamic> entry) => _fromEntry(entry, isRecycled: false);

  /// `getReceivedLikeList`の1件は`SELECT l.*, u.*, ca.alias AS alias`
  /// (`likes`テーブルは`system_id`列を持たず、`ca.alias`も`system_id`と
  /// 無関係な別名のため列重複は起きない)——形状は[fromMatchListEntry]と実質同一。
  factory MatchData.fromReceivedLikeEntry(Map<String, dynamic> entry) => _fromEntry(entry, isRecycled: false);

  /// `spinGacha`の`candidates[]`の1件は`SELECT u.*`の単純な行(joinなし)で、
  /// [fromMatchListEntry]が説明する`getMatchList`特有の列重複は起きない。
  /// フィールド形状は同一なのでパース処理自体は共用する。gacha-redesignで
  /// 追加された`is_recycled`だけ追加で読む。
  factory MatchData.fromGachaCandidate(Map<String, dynamic> entry) =>
      _fromEntry(entry, isRecycled: entry['is_recycled']?.toString() == '1');

  static MatchData _fromEntry(Map<String, dynamic> entry, {required bool isRecycled}) {
    final sexValue = entry['sex']?.toString();
    return MatchData(
      systemId: asBloomInt(entry['system_id']),
      username: (entry['username'] as String?) ?? '',
      sex: sexValue == Sex.female.apiValue ? Sex.female : Sex.male,
      ageId: nullableBloomId(entry['age_id']),
      addressId: nullableBloomId(entry['address_id']),
      incomeId: nullableBloomId(entry['income_id']),
      // 実カラム名は`PR`(`comment`ではない)。gacha-redesign/issues/03の調査で
      // 発覚した既存のパース漏れをここで修正する——旧`comment`キー読み取りは
      // 常に空文字になっていた可能性が高い。
      comment: (entry['PR'] as String?) ?? '',
      photoUrls: [
        resolveBloomAssetUrl(entry['img1_compress_path'] ?? entry['img1_path']),
        resolveBloomAssetUrl(entry['img2_compress_path'] ?? entry['img2_path']),
        resolveBloomAssetUrl(entry['img3_compress_path'] ?? entry['img3_path']),
      ],
      isRecycled: isRecycled,
    );
  }
}
