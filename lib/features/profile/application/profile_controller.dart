import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/bloom_api_client.dart';
import '../domain/profile_data.dart';

part 'profile_controller.g.dart';

@riverpod
class ProfileController extends _$ProfileController {
  @override
  Future<ProfileData> build() async {
    final data = await ref.read(bloomApiClientProvider).callApi('getUserData', {});
    return ProfileData.fromUserData(data['user_data'] as Map<String, dynamic>);
  }

  /// age/income/address/username/reject_matching_mail_flagの一括保存。すべて任意項目
  /// のため、未選択のid類は送らず(既存値を維持)、username/flagは常に送る。
  Future<void> save({
    required String? ageId,
    required String? incomeId,
    required String? addressId,
    required String username,
    required bool rejectMatchingMailFlag,
  }) async {
    state = AsyncLoading<ProfileData>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final data = await ref.read(bloomApiClientProvider).callApi('updateProfile', {
        'age_id': ?ageId,
        'income_id': ?incomeId,
        'address_id': ?addressId,
        'username': username,
        'reject_matching_mail_flag': rejectMatchingMailFlag ? 1 : 0,
      });
      return ProfileData.fromUserData(data['user_data'] as Map<String, dynamic>);
    });
  }

  /// slotは1〜3。base64DataUriは`data:image/xxx;base64,...`形式。
  Future<void> uploadPhoto(int slot, String base64DataUri) async {
    state = AsyncLoading<ProfileData>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final data = await ref.read(bloomApiClientProvider).callApi('uploadProfileImg', {
        'image_$slot': base64DataUri,
      });
      return ProfileData.fromUserData(data['user_data'] as Map<String, dynamic>);
    });
  }

  /// slotは1〜3。
  Future<void> deletePhoto(int slot) async {
    state = AsyncLoading<ProfileData>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final data = await ref.read(bloomApiClientProvider).callApi('deleteProfileImg', {
        'img_id': slot,
      });
      return ProfileData.fromUserData(data['user_data'] as Map<String, dynamic>);
    });
  }
}
