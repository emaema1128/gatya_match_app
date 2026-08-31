import 'package:flutter/material.dart'; // ボタン・テキストなど基本のUI部品(マテリアルデザイン)
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 状態管理ライブラリ「Riverpod」

import '../../../core/network/bloom_api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../matches/domain/match_data.dart'; // ガチャで出てきた「お相手」1人分のデータ
import '../../matches/presentation/profile_details_sheet.dart'; // タップで開く写真ギャラリー+プロフィール詳細シート(いいね/マッチ一覧と共用)
import '../application/gacha_controller.dart'; // ガチャの状態管理・いいね送信などの通信処理
// ConsumerStatefulWidget = Riverpodのref(プロバイダーを読む窓口)が使える、
// かつ状態(State)を持てるウィジェット。
class GachaRevealScreen extends ConsumerStatefulWidget {
  const GachaRevealScreen({super.key});

  @override
  ConsumerState<GachaRevealScreen> createState() => _GachaRevealScreenState();
}

class _GachaRevealScreenState extends ConsumerState<GachaRevealScreen> {
  // PageController = PageView(横にスワイプできるページ切り替え)の
  // 「今どのページを表示しているか」を制御・監視するためのコントローラー。
  late final PageController _pageController = PageController();
  int _index = 0; // 今表示中の候補が何人目か(0始まり)
  bool _isLiking = false; // いいね送信中かどうか(連打で二重送信するのを防ぐためのフラグ)

  // dispose = このウィジェットが画面から消えるときに呼ばれる後片付け処理。
  // Controller系は使い終わったら必ずdispose()してメモリリークを防ぐ。
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // delta(-1で前へ、+1で次へ)の方向にページを移動する。
  // clampで0〜(length-1)の範囲を超えないようにしている(存在しないページに行かないため)。
  void _goTo(int delta, int length) {
    final next = (_index + delta).clamp(0, length - 1);
    _pageController.animateToPage(next, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  // 「いいね」ボタン(カードを上にスワイプ)が押されたときの処理。
  Future<void> _handleLiked(MatchData candidate) async {
    if (_isLiking) return; // 送信中に連打されても何もしない
    setState(() => _isLiking = true);
    try {
      // サーバーにいいねを送信し、マッチが成立したかどうかの結果(true/false)を受け取る。
      final matched = await ref.read(gachaControllerProvider.notifier).likeCandidate(candidate.systemId);
      // mountedチェック = 通信中にこの画面が閉じられていないかの確認。
      // 閉じられていたら、もう画面操作(context操作)はできないのでここで処理を止める。
      if (!mounted) return;
      if (matched) {
        // マッチ成立(お互いにいいね)なら、お祝い画面へ遷移する。
        MatchCelebrationRoute(matchedSystemId: candidate.systemId).push(context);
      } else {
        // マッチ不成立なら、通知(スナックバー)を出してこの画面を閉じる。
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('いいねを送りました')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is BloomApiException ? e.errorDetail : 'いいねの送信に失敗しました。もう一度お試しください。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      // 成功・失敗どちらでも、最後に必ずフラグを戻す(finallyは例外があっても必ず実行される)。
      if (mounted) setState(() => _isLiking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch(...) でガチャの状態を監視し、候補一覧(candidates)だけを取り出す。
    // .value は「通信が成功していればそのデータ、そうでなければnull」を返すので、??演算子で「nullなら空リストを使う」という安全な取り出し方をしている。
    final candidates = ref.watch(gachaControllerProvider).value?.candidates ?? const <MatchData>[];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: candidates.isEmpty ? _buildEmptyFallback(context) : _buildCards(context, candidates),
      ),
    );
  }

  // revealed状態は必ず1人以上を伴うので通常は到達しないが、状態が失われた
  // 場合(ホットリロード、クライアント/サーバーのバージョン不整合等)の保険。
  // 原因が分かりやすいよう、無地の画面ではなくメッセージを出す。
  Widget _buildEmptyFallback(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '候補データを取得できませんでした。\nもう一度ガチャを回してみてください。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 候補カードを横スワイプで切り替えられるメイン画面。
  Widget _buildCards(BuildContext context, List<MatchData> candidates) {
    return Stack(
      // Stack = 複数の要素を重ねて表示する。ここではカードの上に閉じるボタンや矢印ボタン、下部のテキストを重ねて表示している。
      children: [
        // PageView.builder = 横スワイプでページを切り替えられるリスト。
        // itemBuilderは「i番目のページに何を表示するか」を返す関数。
        PageView.builder(
          controller: _pageController,
          itemCount: candidates.length,
          onPageChanged: (i) => setState(() => _index = i), // ページが変わったら_indexを更新
          itemBuilder: (_, i) =>
              _SwipeableProfileCard(candidate: candidates[i], onLiked: () => _handleLiked(candidates[i])),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        // 最初の候補(_index == 0)より前には戻れないので、そのときは矢印を表示しない。
        if (_index > 0)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white, size: 36),
                onPressed: () => _goTo(-1, candidates.length),
              ),
            ),
          ),
        // 最後の候補より後ろには進めないので、そのときは矢印を表示しない。
        if (_index < candidates.length - 1)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white, size: 36),
                onPressed: () => _goTo(1, candidates.length),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Center(
            child: Text(
              '↑ 上にスワイプでいいね ・ ${_index + 1} / ${candidates.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

/// 写真(3/5)+プロフィール情報(2/5)のカード。上方向にドラッグ(または勢いよく
/// フリック)すると[onLiked]を呼ぶ。閾値未満で離すと元の位置に戻る。
/// タップすると画面遷移せず[ProfileDetailsSheet]を開く。
class _SwipeableProfileCard extends ConsumerStatefulWidget {
  const _SwipeableProfileCard({required this.candidate, required this.onLiked});

  final MatchData candidate;
  final VoidCallback onLiked;

  @override
  ConsumerState<_SwipeableProfileCard> createState() => _SwipeableProfileCardState();
}

class _SwipeableProfileCardState extends ConsumerState<_SwipeableProfileCard> {
  // ドラッグで動かした縦方向の距離(y軸)。マイナスが「上方向」。
  double _dragDy = 0;

  // 指でドラッグしている間、毎フレーム呼ばれる。
  // 動かした分(delta.dy)を積み上げていき、範囲外(下に60より大きく引っ張る、上に1000より大きく引っ張る)にはならないようclampで制限している。
  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _dragDy = (_dragDy + details.delta.dy).clamp(-1000.0, 60.0));
  }

  // 指を離したときに呼ばれる。
  // 「勢いよく上にフリックした(primaryVelocityが-600未満)」か、「一定距離(-120)以上、上にドラッグしていた」場合はいいねとみなす。
  // どちらでもなければ、カードを元の位置(_dragDy = 0)に戻す。
  void _onDragEnd(DragEndDetails details) {
    final flungUp = (details.primaryVelocity ?? 0) < -600;
    if (_dragDy < -120 || flungUp) {
      widget.onLiked();
    } else {
      setState(() => _dragDy = 0);
    }
  }

  // カードをタップしたときに、写真ギャラリー+プロフィール詳細のボトムシートを開く(いいね/マッチ一覧と共用の[showProfileDetailsSheet]を利用)。
  void _openDetails(BuildContext context) => showProfileDetailsSheet(context, widget.candidate);

  @override
  Widget build(BuildContext context) {
    // ドラッグ量(_dragDy)が大きい(=上に強く引っ張っている)ほど、
    // カードが薄く(opacity)なり、少し傾く(rotate)ようにして「離れていく感」を出す。
    final opacity = (1 + _dragDy / 400).clamp(0.3, 1.0);
    final rotate = (_dragDy / 2000).clamp(-0.15, 0.15);

    return GestureDetector(
      // GestureDetector = タップやドラッグなどの指の操作を検知するための部品。
      // 自分自身は見た目を持たず、childに指定したウィジェットへの操作を検知する。
      onTap: () => _openDetails(context),
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Transform.translate(
        // Transform.translate = 子要素を指定した分だけ平行移動させる。
        // ここではドラッグ量(_dragDy)そのまま、カードを上下にずらして指に追従させる。
        offset: Offset(0, _dragDy),
        child: Transform.rotate(
          angle: rotate, // 少し傾ける
          child: Opacity(
            opacity: opacity, // 少し透明にする
            child: Padding( // カードの周囲に余白を作る
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 写真: カードの3/5まで。
                      Expanded(flex: 3, child: _buildPhoto(context)),
                      // プロフィール情報: 残り2/5。
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.candidate.username,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (widget.candidate.isRecycled)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Text('以前見たお相手です', style: TextStyle(fontSize: 11)),
                                    ),
                                ],
                              ),
                              // 年齢・住所・年収などのプロフィール情報。
                              const SizedBox(height: 4),
                              if (widget.candidate.comment.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    widget.candidate.comment,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              // 「タップで写真・プロフィールをもっと見る」のヒント。
                              Row(
                                children: [
                                  Icon(Icons.touch_app_outlined, size: 14, color: Theme.of(context).hintColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'タップで写真・プロフィールをもっと見る',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall?.copyWith(color: Theme.of(context).hintColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 候補の写真を表示する。写真が1枚も無い場合は、代わりに人物アイコンを表示する。
  Widget _buildPhoto(BuildContext context) {
    final photoUrl = widget.candidate.photoUrl;
    if (photoUrl == null) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(Icons.person, size: 96, color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    // Image.network = インターネット上のURLから画像を読み込んで表示する。
    return Image.network(photoUrl, fit: BoxFit.cover);
  }
}
