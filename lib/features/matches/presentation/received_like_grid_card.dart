import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/bloom_api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../application/received_like_list_controller.dart';
import '../application/skipped_like_ids_controller.dart';
import '../domain/match_data.dart';
import 'action_button.dart';
import 'profile_photo_overlay.dart';

/// 「いいね」タブの2列グリッド用カード。右スワイプ(または♡ボタン)で
/// いいね返し(マッチ)、左スワイプ(または×ボタン)で拒否(スキップ)する。
/// タップすると[ReceivedLikeDetailRoute]のフルスクリーン詳細ページへ遷移する。
///
/// 拒否は現状サーバーに永続化されない暫定実装
/// ([SkippedLikeIdsController]参照)。
class ReceivedLikeGridCard extends ConsumerStatefulWidget {
  const ReceivedLikeGridCard({super.key, required this.match});

  final MatchData match;

  @override
  ConsumerState<ReceivedLikeGridCard> createState() => _ReceivedLikeGridCardState();
}

class _ReceivedLikeGridCardState extends ConsumerState<ReceivedLikeGridCard> {
  // 横方向のドラッグ量(x軸)。プラスが右方向(マッチ)、マイナスが左方向(拒否)。
  double _dragDx = 0;
  bool _isSubmitting = false;

  void _onDragUpdate(DragUpdateDetails details) {
    if (_isSubmitting) return;
    setState(() => _dragDx = (_dragDx + details.delta.dx).clamp(-200.0, 200.0));
  }

  // 「勢いよくフリックした」か「一定距離以上ドラッグした」場合に決定とみなす。
  // ガチャ排出画面([_SwipeableProfileCard])の縦方向版と同じ考え方の横方向版。
  void _onDragEnd(DragEndDetails details) {
    if (_isSubmitting) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_dragDx > 100 || velocity > 600) {
      _handleMatch();
    } else if (_dragDx < -100 || velocity < -600) {
      _handleSkip();
    } else {
      setState(() => _dragDx = 0);
    }
  }

  void _handleSkip() {
    ref.read(skippedLikeIdsControllerProvider.notifier).add(widget.match.systemId);
  }

  Future<void> _handleMatch() async {
    setState(() => _isSubmitting = true);
    try {
      final matched = await ref
          .read(receivedLikeListControllerProvider.notifier)
          .returnLike(widget.match.systemId);
      if (!mounted) return;
      if (matched) {
        MatchCelebrationRoute(matchedSystemId: widget.match.systemId).push(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('いいねを送りました')));
        setState(() => _dragDx = 0);
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is BloomApiException ? e.errorDetail : 'いいねの送信に失敗しました。もう一度お試しください。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _dragDx = 0);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final opacity = (1 - _dragDx.abs() / 300).clamp(0.4, 1.0);
    final rotate = (_dragDx / 1200).clamp(-0.12, 0.12);

    return GestureDetector(
      onTap: _isSubmitting ? null : _openDetail, // タップで詳細ページへ遷移する。
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Transform.translate(
        offset: Offset(_dragDx, 0),
        child: Transform.rotate(
          angle: rotate,
          child: Opacity(opacity: opacity, child: _buildCard(context)),
        ),
      ),
    );
  }

  void _openDetail() {
    ReceivedLikeDetailRoute(systemId: widget.match.systemId).push(context);
  }

  Widget _buildCard(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ProfilePhotoOverlay(match: widget.match),
                if (_isSubmitting) // いいね返し中。
                  const ColoredBox(
                    color: Colors.black38,
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ActionButton(
                  label: 'スキップ',
                  color: Colors.grey.shade600,
                  onTap: _isSubmitting ? null : _handleSkip,
                ),
                ActionButton(
                  label: 'マッチ',
                  color: Colors.pinkAccent,
                  onTap: _isSubmitting ? null : _handleMatch,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
