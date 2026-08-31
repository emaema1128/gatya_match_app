import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/sex.dart';
import '../../../core/profile/profile_option_list_provider.dart';
import '../domain/match_data.dart';

/// タップで開く、写真ギャラリー+フルのプロフィール情報のオーバーレイ。
/// `showModalBottomSheet`で開く想定(呼び出し元は画面遷移しない、その場に重ねて表示)。
///
/// ガチャ排出画面([gacha-redesign/issues/05](../../../../.scratch/gacha-redesign/issues/05-gacha-home-screen-revamp-implementation.md))
/// で最初に実装された方式を、いいね/マッチ一覧・マッチ成立演出画面([gacha-redesign/issues/07](../../../../.scratch/gacha-redesign/issues/07-list-card-profile-view-navigation.md))
/// でも共用できるよう、共通ウィジェットとして切り出したもの。
class ProfileDetailsSheet extends ConsumerStatefulWidget {
  const ProfileDetailsSheet({super.key, required this.match});

  final MatchData match;

  @override
  ConsumerState<ProfileDetailsSheet> createState() => _ProfileDetailsSheetState();
}

class _ProfileDetailsSheetState extends ConsumerState<ProfileDetailsSheet> {
  final _photoController = PageController(); // ギャラリー内の写真ページ送り用
  int _photoIndex = 0; // ギャラリーで今何枚目の写真を見ているか

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // whereType<String>() = リストの中からString型の要素だけを取り出す
    // (nullが混ざっている可能性のあるリストから、有効なURLだけを残す)。
    final photos = widget.match.photoUrls.whereType<String>().toList();

    return DraggableScrollableSheet(
      // DraggableScrollableSheet = 下からせり上がる、指でドラッグして
      // 高さを変えられるシート(ボトムシート)。
      initialChildSize: 0.85, // 開いた直後の高さ(画面の85%)
      minChildSize: 0.5, // 縮められる最小の高さ(画面の50%)
      maxChildSize: 0.95, // 広げられる最大の高さ(画面の95%)
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 8),
            // シート上部の「つまみ」のような横長の小さいバー(見た目だけの飾り)。
            // これがあることで「指でドラッグして開閉できる」ことが視覚的に伝わる。
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Theme.of(context).hintColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(height: 320, child: _buildPhotoGallery(context, photos)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.match.username,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildOptionRow(context, ref),
                  const SizedBox(height: 16),
                  Text('プロフィール', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    widget.match.comment.isEmpty ? '自己紹介はまだありません。' : widget.match.comment,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // 複数枚の写真を横スワイプで見られるギャラリー。写真が2枚以上あるときは、
  // 上部に「今何枚目か」を示すインジケーター(細長いバーの並び)も表示する。
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
          itemCount: photos.length,
          onPageChanged: (i) => setState(() => _photoIndex = i),
          itemBuilder: (_, i) => Image.network(photos[i], fit: BoxFit.cover, width: double.infinity),
        ),
        if (photos.length > 1)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              // List.generate(枚数, ...) で写真の枚数分だけ小さいバーを作る。
              // 今表示中のインデックス(_photoIndex)と一致するバーだけ白く光らせ、
              // それ以外は薄い色(white38)にすることで現在地を示す。
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
    );
  }

  // 年齢・住所・年収など、設定されているプロフィール項目を「・」区切りの
  // 1行のテキストにまとめて表示する(どれも未設定なら何も表示しない)。
  Widget _buildOptionRow(BuildContext context, WidgetRef ref) {
    final labels = [
      _resolveOptionLabel(ref.watch(ageOptionListProvider), widget.match.ageId, widget.match.sex),
      _resolveOptionLabel(ref.watch(addressOptionListProvider), widget.match.addressId, widget.match.sex),
      _resolveOptionLabel(ref.watch(incomeOptionListProvider), widget.match.incomeId, widget.match.sex),
    ].whereType<String>().toList(); // nullを除いた「実際に表示できるラベル」だけを残す
    if (labels.isEmpty) return const SizedBox.shrink();
    return Text(labels.join(' ・ '), style: Theme.of(context).textTheme.bodyMedium);
  }

  // 相手が持っている「選択肢のID」(例: 年齢ID)から、実際に画面に表示する
  // 日本語の文言(例: "20代")を選択肢一覧の中から探して返す。
  // 見つからない場合(idが未設定/一覧未取得/該当なし)はnullを返す。
  String? _resolveOptionLabel(AsyncValue<List<ProfileOption>> optionsAsync, String? id, Sex sex) {
    if (id == null) return null;
    final options = optionsAsync.value;
    if (options == null) return null;
    final matching = options.where((option) => option.sex == sex.apiValue && option.id == id);
    return matching.isEmpty ? null : matching.first.item;
  }
}

/// [ProfileDetailsSheet]を`showModalBottomSheet`で開くための共通ヘルパー。
/// 画面遷移はせず、その場に重ねて表示する。
void showProfileDetailsSheet(BuildContext context, MatchData match) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // 画面の高さいっぱいまで広げられるようにする
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => ProfileDetailsSheet(match: match),
  );
}
