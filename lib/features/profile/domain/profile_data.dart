import '../../../core/auth/sex.dart';
import '../../../core/network/bloom_field_parsers.dart';

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
    required this.balance,
  });

  final Sex sex;
  final String? ageId;
  final String? incomeId;
  final String? addressId;
  final String username;
  final bool rejectMatchingMailFlag;

  /// インデックス0/1/2がbloomのimg1/img2/img3スロットに対応。空スロットはnull。
  final List<String?> photoUrls;

  /// マイページホーム画面の「残ポイント」表示用(gacha_controller.dartと同じ`getUserData`の
  /// `balance`を読んでいるだけで、別APIは叩いていない)。
  final int balance;

  factory ProfileData.fromUserData(Map<String, dynamic> userData) {
    final sexValue = userData['sex']?.toString();
    return ProfileData(
      sex: sexValue == Sex.female.apiValue ? Sex.female : Sex.male,
      ageId: nullableBloomId(userData['age_id']),
      incomeId: nullableBloomId(userData['income_id']),
      addressId: nullableBloomId(userData['address_id']),
      username: (userData['username'] as String?) ?? '',
      rejectMatchingMailFlag: userData['reject_matching_mail_flag']?.toString() == '1',
      photoUrls: [
        resolveBloomAssetUrl(userData['img1_compress_path'] ?? userData['img1_path']),
        resolveBloomAssetUrl(userData['img2_compress_path'] ?? userData['img2_path']),
        resolveBloomAssetUrl(userData['img3_compress_path'] ?? userData['img3_path']),
      ],
      balance: asBloomInt(userData['balance']),
    );
  }
}
