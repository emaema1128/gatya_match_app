// ガチャホーム画面用のRiverpodコントローラーで、残高取得（build）・ガチャ実行（spin）・いいね送信＋マッチ時のキャッシュ無効化（likeCandidate）を担うファイル
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/bloom_api_client.dart';
import '../../../core/network/bloom_field_parsers.dart';
import '../../matches/application/match_list_controller.dart';
import '../../matches/application/received_like_list_controller.dart';
import '../../matches/domain/match_data.dart';
import '../domain/gacha_home_state.dart';
import '../domain/gacha_spin_status.dart';

// riverpod_annotationが`@riverpod`を見て、この名前(gacha_controller.g.dart)でProviderの実装コード(_$GachaControllerなど)を自動生成する。
//`dart run build_runner build`で更新される。
part 'gacha_controller.g.dart';

// `@riverpod`を付けたクラスは`AsyncNotifier`(非同期な状態を持つコントローラー)として動作する。
// 画面側は`gachaControllerProvider`を`watch`してこの状態(GachaHomeState)を購読し、状態が変わるたびに再描画される。
@riverpod
class GachaController extends _$GachaController {
  // このProviderが最初にwatchされたときに1回だけ呼ばれ、初期状態を作る。
  // 戻り値の型がFutureなので、呼び出し側からはロード中はAsyncLoading、成功時はAsyncData(GachaHomeState)として見える。
  @override
  Future<GachaHomeState> build() async {
    // サーバーAPIを呼んでログイン中ユーザーのデータを取得する。
    final data = await ref.read(bloomApiClientProvider).callApi('getUserData', {});
    // サーバーの数値はint/String/doubleのいずれで返ってくるか保証がないため、asBloomIntで安全にint型へ変換する。
    final balance = asBloomInt((data['user_data'] as Map<String, dynamic>)['balance']);
    // 初期状態はガチャ未実行(idle)、候補は空。
    return GachaHomeState(balance: balance, status: GachaSpinStatus.idle, candidates: const []);
  }

  // 「ガチャを回す」ボタンから呼ばれる。ポイントを消費してお相手候補を抽選する。
  Future<void> spin() async {
    // 単なるAsyncLoading()にすると画面が一瞬白紙(ロード中)表示に戻ってしまう。
    // copyWithPreviousで直前の値(state)を保持しておくと、画面側は「ロード中だが直前のデータもある」状態として扱え、残高表示などがちらつかずに済む。
    state = AsyncLoading<GachaHomeState>().copyWithPrevious(state);

    // AsyncValue.guardは中のコードを実行し、
    // ・例外が出なければ結果をAsyncData(成功)として、
    // ・例外が出ればAsyncError(失敗)として、
    // 自動的にstateへ変換してくれる。try/catchを自分で書かなくてよい。
    state = await AsyncValue.guard(() async {
      final data = await ref.read(bloomApiClientProvider).callApi('spinGacha', {});

      // サーバーが返す文字列のstatus('revealed'など)をアプリ内のenumに変換する。
      final status = gachaSpinStatusFromApi(data['status'] as String);

      // candidatesがnullの場合(該当なし)は空リストとして扱う。
      final candidatesJson = (data['candidates'] as List<dynamic>?) ?? const [];
      final candidates = candidatesJson
          .map((entry) => MatchData.fromGachaCandidate(entry as Map<String, dynamic>))
          .toList();

      // ガチャ失敗(ポイント不足など)時はuser_dataが返ってこないことがあるため、その場合は直前のstateに入っていた残高をそのまま使う(0にリセットしない)。
      final userData = data['user_data'] as Map<String, dynamic>?;
      final balance = userData != null ? asBloomInt(userData['balance']) : state.value?.balance ?? 0;

      return GachaHomeState(balance: balance, status: status, candidates: candidates);
    });
  }

  /// AsyncValueを経由しないのは、失敗時に候補カード表示を壊さないため。
  /// マッチ成立時はtrueを返し、遷移は呼び出し元(画面)が担当する。
  Future<bool> likeCandidate(int targetId) async {
    final data = await ref.read(bloomApiClientProvider).callApi('sendLike', {'target_id': targetId});
    final matched = data['status'] == 'match';
    if (matched) {
      // ref.invalidateは対象Providerのキャッシュを破棄する。次にwatch/readされた時点でbuild()が再実行され、最新のマッチ一覧をサーバーから取り直す。
      ref.invalidate(matchListControllerProvider);
      // マッチ成立でlikes.statusがMATCHに変わりgetReceivedLikeListのWHERE句から外れるため、受け取ったいいね一覧のキャッシュも無効化する。
      ref.invalidate(receivedLikeListControllerProvider);
    }
    return matched;
  }
}
