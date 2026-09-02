import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'blocked_talk_ids_controller.g.dart';

/// チャット一覧でブロックした相手のtargetId(system_id)を保持する。
///
/// ブロックは`updateContactNg`でサーバーにも送信するが、
/// `getMailListForMatching`がNG済みの相手を実際に除外して返すかは未確認のため、
/// 除外されなかった場合でも一覧から即座に消えるよう、アプリ内メモリ側でも
/// 二重に隠す([SkippedLikeIdsController]と同じ考え方)。アプリを再起動すると
/// このメモリ上の記録は失われるが、サーバー側のNG登録が効いていれば
/// 再取得時にも一覧から除外され続ける想定。
///
/// [TalkListController]とは別Providerにしているのは、一覧の再取得
/// (refresh/invalidate)があってもブロック済み一覧が消えないようにするため。
@riverpod
class BlockedTalkIdsController extends _$BlockedTalkIdsController {
  @override
  Set<int> build() => {};

  void add(int targetId) {
    state = {...state, targetId};
  }
}
