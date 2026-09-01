import 'package:flutter/material.dart';

import '../domain/match_data.dart';
import 'profile_details_sheet.dart';
import 'profile_photo_overlay.dart';

/// 「マッチ」タブの2列グリッド用カード。タップすると[ProfileDetailsSheet]を開く。
/// マッチ済みの相手にはスキップ/いいね返しの意思決定が不要なため、
/// [ReceivedLikeGridCard]と違いスワイプ操作やアクションボタンは持たない。
class MatchGridCard extends StatelessWidget {
  const MatchGridCard({super.key, required this.match});

  final MatchData match;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showProfileDetailsSheet(context, match),
        child: ProfilePhotoOverlay(match: match),
      ),
    );
  }
}
