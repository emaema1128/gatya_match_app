import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/profile/profile_option_list_provider.dart';
import '../domain/match_data.dart';
import 'profile_details_sheet.dart';

/// いいね一覧・マッチ一覧・マッチ成立画面で共通の、相手プロフィールの抜粋カード。
/// 写真+ニックネーム+年齢+居住地+自己紹介の冒頭を表示する
/// ([stage3-gacha-home/issues/03-ui-flow-design](../../../../.scratch/stage3-gacha-home/issues/03-ui-flow-design.md)
/// で決めた「結果カードは抜粋版」の方針をStage4のマッチ表示にも適用)。
///
/// タップすると画面遷移せず、[ProfileDetailsSheet]で写真ギャラリー+プロフィール詳細
/// を表示する([gacha-redesign/issues/07](../../../../.scratch/gacha-redesign/issues/07-list-card-profile-view-navigation.md))。
class MatchProfileCard extends ConsumerWidget {
  const MatchProfileCard({super.key, required this.match});

  final MatchData match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      // InkWell = タップを検知しつつ、タップ時に波紋(リップル)が広がる
      // アニメーションを出してくれるWidget。Cardの角丸に合わせてborderRadiusも指定する。
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showProfileDetailsSheet(context, match),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhoto(context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(match.username, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildOptionLabel(ref.watch(ageOptionListProvider), match.ageId),
                        const SizedBox(width: 8),
                        _buildOptionLabel(ref.watch(addressOptionListProvider), match.addressId),
                      ],
                    ),
                    if (match.comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        match.comment,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoto(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 72,
        height: 72,
        child: match.photoUrl == null
            ? Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.person_outline),
              )
            : Image.network(match.photoUrl!, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildOptionLabel(AsyncValue<List<ProfileOption>> optionsAsync, String? id) {
    if (id == null) return const SizedBox.shrink();

    return optionsAsync.when(
      data: (options) {
        final matching = options.where((option) => option.sex == match.sex.apiValue && option.id == id);
        if (matching.isEmpty) return const SizedBox.shrink();
        return Text(matching.first.item, style: const TextStyle(fontSize: 13));
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
