import 'package:flutter/material.dart';
// Riverpod: 状態管理(データの保持・共有)のためのパッケージ。
// ref.watch / ref.read などはこのパッケージが提供する仕組み。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/bloom_api_exception.dart';
// Controller = APIからデータを取得し、画面に渡す役割を持つクラス(状態管理の中心)。
import '../application/match_list_controller.dart';
import '../application/received_like_list_controller.dart';
// MatchData = マッチ相手1件分のデータを表すモデルクラス。
import '../domain/match_data.dart';
import 'match_profile_card.dart';

enum _LikeMatchSegment { received, matched }

class MatchListScreen extends ConsumerStatefulWidget {
  const MatchListScreen({super.key});

  @override
  ConsumerState<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends ConsumerState<MatchListScreen> {
  // 現在選ばれているセグメント(タブ)。初期値は「いいね(受け取った)」。
  // setState()で更新すると、Flutterがbuild()を再実行して画面を描き直してくれる。
  _LikeMatchSegment _segment = _LikeMatchSegment.received;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Scaffold = 画面の土台となるWidget。AppBar(上部バー)やbody(本体)をまとめて配置できる。
      appBar: AppBar(title: const Text('like')),
      // SafeArea = ノッチ(切り欠き)やステータスバーに被らないよう、余白を自動で入れてくれるWidget。
      body: SafeArea(
        // Column = 子Widgetを縦に並べるWidget。
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              // SegmentedButton = 複数の選択肢からひとつを選ぶ、いわゆる「切り替えタブ」のUI部品。
              child: SegmentedButton<_LikeMatchSegment>(
                segments: const [
                  ButtonSegment(value: _LikeMatchSegment.received, label: Text('いいね')),
                  ButtonSegment(value: _LikeMatchSegment.matched, label: Text('マッチ')),
                ],
                // selected: 現在選ばれている値の集合(SegmentedButtonの仕様上Setで渡す)。
                selected: {_segment},
                // ユーザーがタップして選択を変えたときに呼ばれる。
                // selected.first で選ばれた1件を取り出し、_segmentを更新している。
                onSelectionChanged: (selected) => setState(() => _segment = selected.first),
              ),
            ),
            Expanded(
              child: switch (_segment) {
                _LikeMatchSegment.received => const _ReceivedLikeTab(),
                _LikeMatchSegment.matched => const _MatchTab(),
              },
            ),
          ],
        ),
      ),
    );
  }
}


// 「いいね(受け取った・未マッチ)」タブの中身。
// ConsumerWidget = StatelessWidgetのRiverpod版。自前のStateは持たず、
// 状態(データ)はすべてProvider側(Controller)に持たせる。
class _ReceivedLikeTab extends ConsumerWidget {
  const _ReceivedLikeTab();

  // WidgetRef ref: Providerとやり取りするための道具。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch: Providerの値を「購読」する。値が変わるたびbuild()が自動で再実行される。
    // AsyncValue<...> = 「読み込み中 / 成功 / エラー」の3状態をまとめて表す型(API通信の結果によく使う)。
    final receivedLikesAsync = ref.watch(receivedLikeListControllerProvider);
    // RefreshIndicator = 画面を下に引っ張ると再読み込みできる、いわゆる「pull to refresh」。
    return RefreshIndicator(
      // ref.read: watchと違い「今の値を1回だけ読む」。
      // ボタン操作などのイベントハンドラ内ではread、build()内の表示にはwatchを使うのが基本。
      onRefresh: () => ref.read(receivedLikeListControllerProvider.notifier).refresh(),
      child: _buildBody(
        context,
        receivedLikesAsync,
        emptyMessage: 'まだいいねが届いていません。',
      ),
    );
  }
}

/// マッチ済みセグメント(旧・単一「Like」タブの中身)。
class _MatchTab extends ConsumerWidget {
  const _MatchTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchListControllerProvider);
    return RefreshIndicator(
      onRefresh: () => ref.read(matchListControllerProvider.notifier).refresh(),
      child: _buildBody(
        context,
        matchesAsync,
        emptyMessage: 'まだマッチしたお相手がいません。ホームでガチャを回してみましょう。',
      ),
    );
  }
}

// 「いいね」タブと「マッチ」タブは表示ロジックが同じなので、共通の関数にまとめている。
// AsyncValue.when(...) は、data/loading/errorの3状態それぞれに対して
// 「その状態のときは何を表示するか」を書ける便利なメソッド。
Widget _buildBody(BuildContext context, AsyncValue<List<MatchData>> matchesAsync, {required String emptyMessage}) {
  return matchesAsync.when(
    // data: 読み込み成功時。matchesは実際のデータ(リスト)。
    data: (matches) => matches.isEmpty ? _buildEmptyState(context, emptyMessage) : _buildList(matches),
    // loading: 読み込み中。ぐるぐる回るインジケーターを画面中央に表示する。
    loading: () => const Center(child: CircularProgressIndicator()),
    // error: 通信エラーなどが起きたとき。
    error: (error, _) => _buildErrorState(context, error),
  );
}

// データが1件以上あるときの一覧表示。
Widget _buildList(List<MatchData> matches) {
  // ListView.builder = 表示される分だけWidgetを作る(画面外のアイテムは作らない)ので、
  // 件数が多くても軽く動く。
  return ListView.builder(
    padding: const EdgeInsets.all(12),
    itemCount: matches.length,
    // itemBuilder: リストの各行(index番目)をどう表示するか。
    itemBuilder: (context, index) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MatchProfileCard(match: matches[index]),
    ),
  );
}

// データが0件のときのメッセージ表示。
Widget _buildEmptyState(BuildContext context, String message) {
  // LayoutBuilder + ConstrainedBox(minHeight) + SingleChildScrollView の組み合わせは、
  // 「中身が短くても画面いっぱいの高さを確保しつつ、スクロール(pull to refresh)も
  // 効かせ続ける」ための定番パターン。単にCenterだけだと、
  // 親のRefreshIndicatorが引っ張り動作を検知できなくなることがあるための工夫。
  return LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
      ),
    ),
  );
}

// 通信エラーなどが起きたときのメッセージ表示。
Widget _buildErrorState(BuildContext context, Object error) {
  // BloomApiExceptionであれば、サーバーが返した詳細メッセージを表示。
  // それ以外の想定外のエラーでは、汎用的な案内文を表示する。
  final message = error is BloomApiException ? error.errorDetail : '通信状態を確認してください。';
  // ここも_buildEmptyStateと同じ理由でLayoutBuilder+ScrollViewの組み合わせを使っている。
  return LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      ),
    ),
  );
}
