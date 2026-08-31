import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/bloom_api_client.dart';
import '../domain/profile_data.dart';

part 'profile_controller.g.dart';

@riverpod
class ProfileController extends _$ProfileController {
  // サーバーから自分のプロフィール情報を取得している。
  // 戻り値の型がFuture<ProfileData>なので、Riverpodが自動で「読み込み中→成功/失敗」というAsyncValueの状態管理をしてくれる。
  @override
  Future<ProfileData> build() async {
    final data = await ref.read(bloomApiClientProvider).callApi('getUserData', {});
    // APIの生レスポンス(Map)を、画面で使いやすい型付きのProfileDataに変換する。
    return ProfileData.fromUserData(data['user_data'] as Map<String, dynamic>);
  }

  /// age/income/address/username/reject_matching_mail_flagの一括保存。
  /// すべて任意項目のため、未選択のid類は送らず(既存値を維持)、username/flagは常に送る。
  Future<void> save({
    required String? ageId,
    required String? incomeId,
    required String? addressId,
    required String username,
    required bool rejectMatchingMailFlag,
  }) async {
    // state = ... : Notifierの現在の状態を書き換える。
    // ここに代入すると、このプロバイダーをwatchしている画面が自動的に再描画される。
    // AsyncLoading().copyWithPrevious(state): 「読み込み中」状態にしつつ、直前のデータ(前回のProfileData)も一緒に保持しておく。
    // 保存中も画面が真っ白なローディング表示に切り替わらず、更新前の内容を表示し続けられる(細かいUXへの配慮)。
    state = AsyncLoading<ProfileData>().copyWithPrevious(state);
    // AsyncValue.guard(...): 渡した非同期処理を実行し、
    // ・成功したら結果をAsyncData(成功状態)に、
    // ・例外が起きたらAsyncError(失敗状態)に、
    // 自動で変換してくれるヘルパー。try/catchを自分で書かなくてよくなる。
    state = await AsyncValue.guard(() async {
      final data = await ref.read(bloomApiClientProvider).callApi('updateProfile', {
        // 'key': ?value という書き方(null-aware要素)は、valueがnullのときはこのキー自体をMapに含めない、という意味。
        // 「未選択の項目は送らない(サーバー側の既存値を上書きしない)」を表現するために使っている。
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
        // Map内の $slot は文字列補間。slot=2なら'image_2'というキーになる。
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
