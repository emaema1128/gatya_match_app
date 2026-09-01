import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/sex.dart';
import '../../../core/network/bloom_api_exception.dart';
import '../../../core/profile/profile_option_list_provider.dart';
import '../../../core/router/app_routes.dart';
import '../application/received_like_list_controller.dart';
import '../application/skipped_like_ids_controller.dart';
import '../domain/match_data.dart';
import 'action_button.dart';

/// 「いいね」タブのグリッドカードをタップすると開く、フルスクリーンの
/// プロフィール詳細ページ。
///
/// [ProfileDetailsSheet]と役割は近いが、こちらはカード全体の左右フリックで
/// マッチ/拒否の意思決定を行うため、写真の切り替えは横スワイプではなく
/// 「画像の左右端をタップ」方式にしている(横ドラッグをすべて意思決定用に
/// 空けるため)。この横方向ジェスチャーの都合上、ボトムシートではなく
/// 専用の画面として実装している。
class ReceivedLikeDetailScreen extends ConsumerStatefulWidget {
  const ReceivedLikeDetailScreen({super.key, required this.systemId});

  final int systemId;

  @override
  ConsumerState<ReceivedLikeDetailScreen> createState() => _ReceivedLikeDetailScreenState();
}

class _ReceivedLikeDetailScreenState extends ConsumerState<ReceivedLikeDetailScreen> {
  final _photoController = PageController();
  int _photoIndex = 0;
  double _dragDx = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  void _goToPhoto(int delta, int length) {
    final next = (_photoIndex + delta).clamp(0, length - 1);
    if (next == _photoIndex) return;
    _photoController.animateToPage(next, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_isSubmitting) return;
    setState(() => _dragDx = (_dragDx + details.delta.dx).clamp(-250.0, 250.0));
  }

  void _onDragEnd(DragEndDetails details, MatchData match) {
    if (_isSubmitting) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_dragDx > 120 || velocity > 600) {
      _handleMatch(match);
    } else if (_dragDx < -120 || velocity < -600) {
      _handleSkip(match);
    } else {
      setState(() => _dragDx = 0);
    }
  }

  void _handleSkip(MatchData match) {
    ref.read(skippedLikeIdsControllerProvider.notifier).add(match.systemId);
    Navigator.of(context).pop();
  }

  Future<void> _handleMatch(MatchData match) async {
    setState(() => _isSubmitting = true);
    try {
      final matched = await ref.read(receivedLikeListControllerProvider.notifier).returnLike(match.systemId);
      if (!mounted) return;
      if (matched) {
        MatchCelebrationRoute(matchedSystemId: match.systemId).push(context).then((_) {
          if (mounted) Navigator.of(context).pop();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('いいねを送りました')));
        Navigator.of(context).pop();
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
    final receivedLikesAsync = ref.watch(receivedLikeListControllerProvider);

    return Scaffold(
      appBar: AppBar(),
      body: receivedLikesAsync.when(
        data: (matches) {
          final matching = matches.where((m) => m.systemId == widget.systemId);
          final match = matching.isEmpty ? null : matching.first;
          if (match == null) {
            return const Center(child: Text('お相手の情報を取得できませんでした。'));
          }
          return _buildContent(context, match);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('お相手の情報を取得できませんでした。')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, MatchData match) {
    final photos = match.photoUrls.whereType<String>().toList();
    final opacity = (1 - _dragDx.abs() / 400).clamp(0.4, 1.0);
    final rotate = (_dragDx / 1600).clamp(-0.1, 0.1);

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: (details) => _onDragEnd(details, match),
              child: Transform.translate(
                offset: Offset(_dragDx, 0),
                child: Transform.rotate(
                  angle: rotate,
                  child: Opacity(
                    opacity: opacity,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 360, child: _buildPhotoGallery(context, photos)),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  match.username,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                _buildOptionRow(context, match),
                                const SizedBox(height: 16),
                                Text('プロフィール', style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 8),
                                Text(
                                  match.comment.isEmpty ? '自己紹介はまだありません。' : match.comment,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
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
          _buildActionBar(match),
        ],
      ),
    );
  }

  Widget _buildActionBar(MatchData match) {
    if (_isSubmitting) {
      return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ActionButton(
            label: 'スキップ',
            color: Colors.grey.shade600,
            size: 56,
            horizontalPadding: 36,
            onTap: () => _handleSkip(match),
          ),
          ActionButton(
            label: 'マッチ',
            color: Colors.pinkAccent,
            size: 64,
            horizontalPadding: 44,
            onTap: () => _handleMatch(match),
          ),
        ],
      ),
    );
  }

  // 複数枚の写真を「左右端をタップ」でめくれるギャラリー。横スワイプでは
  // なくタップにしているのは、横ドラッグをカード全体のマッチ/拒否判定に
  // 使うため(親のGestureDetectorとジェスチャーが競合しないようにする)。
  Widget _buildPhotoGallery(BuildContext context, List<String> photos) {
    if (photos.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(Icons.person, size: 120, color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Stack(
      children: [
        PageView.builder(
          controller: _photoController,
          // 写真送りはタップ操作のみで行うため、PageView自体のドラッグは無効化する。
          physics: const NeverScrollableScrollPhysics(),
          itemCount: photos.length,
          onPageChanged: (i) => setState(() => _photoIndex = i),
          itemBuilder: (_, i) => Image.network(photos[i], fit: BoxFit.cover, width: double.infinity),
        ),
        if (photos.length > 1) ...[
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.35,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _goToPhoto(-1, photos.length),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.35,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _goToPhoto(1, photos.length),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: List.generate(
                photos.length,
                (i) => Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i == _photoIndex ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOptionRow(BuildContext context, MatchData match) {
    final labels = [
      _resolveOptionLabel(ref.watch(ageOptionListProvider), match.ageId, match.sex),
      _resolveOptionLabel(ref.watch(addressOptionListProvider), match.addressId, match.sex),
      _resolveOptionLabel(ref.watch(incomeOptionListProvider), match.incomeId, match.sex),
    ].whereType<String>().toList();
    if (labels.isEmpty) return const SizedBox.shrink();
    return Text(labels.join(' ・ '), style: Theme.of(context).textTheme.bodyMedium);
  }

  String? _resolveOptionLabel(AsyncValue<List<ProfileOption>> optionsAsync, String? id, Sex sex) {
    if (id == null) return null;
    final options = optionsAsync.value;
    if (options == null) return null;
    final matching = options.where((option) => option.sex == sex.apiValue && option.id == id);
    return matching.isEmpty ? null : matching.first.item;
  }
}
