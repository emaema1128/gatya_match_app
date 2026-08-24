import '../../../core/auth/sex.dart';

// TODO: bloomの画像配信ベースURLは`https://bloom-developer.com/` + 保存パスと推測
// しているが未検証(実際に写真をアップロードして表示確認するまでは仮定)。
const _kBloomBaseUrl = 'https://bloom-developer.com/';

/// `getUserData`から読み取ったProfile画面向けの表示用データ。
class ProfileData {
  const ProfileData({
    required this.sex,
    required this.ageId,
    required this.incomeId,
    required this.addressId,
    required this.username,
    required this.rejectMatchingMailFlag,
    required this.photoUrls,
  });

  final Sex sex;
  final String? ageId;
  final String? incomeId;
  final String? addressId;
  final String username;
  final bool rejectMatchingMailFlag;

  /// インデックス0/1/2がbloomのimg1/img2/img3スロットに対応。空スロットはnull。
  final List<String?> photoUrls;

  factory ProfileData.fromUserData(Map<String, dynamic> userData) {
    final sexValue = userData['sex']?.toString();
    return ProfileData(
      sex: sexValue == Sex.female.apiValue ? Sex.female : Sex.male,
      ageId: _nullableId(userData['age_id']),
      incomeId: _nullableId(userData['income_id']),
      addressId: _nullableId(userData['address_id']),
      username: (userData['username'] as String?) ?? '',
      rejectMatchingMailFlag: userData['reject_matching_mail_flag']?.toString() == '1',
      photoUrls: [
        _photoUrl(userData['img1_compress_path'] ?? userData['img1_path']),
        _photoUrl(userData['img2_compress_path'] ?? userData['img2_path']),
        _photoUrl(userData['img3_compress_path'] ?? userData['img3_path']),
      ],
    );
  }

  static String? _nullableId(Object? value) {
    if (value == null) return null;
    final str = value.toString();
    return (str.isEmpty || str == '0') ? null : str;
  }

  static String? _photoUrl(Object? path) {
    final str = path as String?;
    if (str == null || str.isEmpty) return null;
    return '$_kBloomBaseUrl$str';
  }
}
