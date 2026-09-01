import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'skipped_like_ids_controller.g.dart';

/// 「いいね」タブで拒否(スキップ)した相手のsystem_idを保持する。
///
/// 拒否のサーバー永続化(`likes.status`を`STATUS_REJECT`にする処理)は
/// このリポジトリの外にあるバックエンド(`Class_Likes.php`、bloom本体側)の
/// 対応が必要なため未実装——このProviderはアプリ内メモリのみで拒否済みを
/// 一覧から隠す暫定実装で、アプリを再起動すると一覧に戻ってきてしまう。
/// バックエンド対応が整い次第、サーバー呼び出しに置き換える想定。
///
/// [ReceivedLikeListController]とは別Providerにしているのは、一覧の
/// 再取得(refresh/invalidate)があっても拒否済み一覧が消えないようにするため
/// (受信いいね一覧のプロバイダー自体を都度作り直すと、インスタンスに
/// 持たせた拒否済みセットも一緒にリセットされてしまう)。
@riverpod
class SkippedLikeIdsController extends _$SkippedLikeIdsController {
  @override
  Set<int> build() => {};

  void add(int systemId) {
    state = {...state, systemId};
  }
}
