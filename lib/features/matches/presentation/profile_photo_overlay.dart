import 'package:flutter/material.dart';

import '../domain/match_data.dart';

/// 写真いっぱいに広がる背景の下部に、名前と自己紹介文をグラデーションで
/// 重ねて表示するカードの中身。[ReceivedLikeGridCard]と
/// [MatchCelebrationScreen]で共通利用する。
class ProfilePhotoOverlay extends StatelessWidget {
  const ProfilePhotoOverlay({
    super.key,
    required this.match,
    this.usernameFontSize = 14,
    this.commentFontSize = 12,
  });

  final MatchData match;

  /// 名前・自己紹介文のフォントサイズ。表示先のカードの大きさに応じて
  /// 呼び出し元で調整する(グリッドカードは小さめ、マッチ成立画面は大きめ)。
  final double usernameFontSize;
  final double commentFontSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildPhoto(context),
        Positioned(
          // 写真の下に名前・自己紹介文を重ねて表示する。
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.username, // 名前を表示する。長すぎる場合は省略して1行まで表示。
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: usernameFontSize),
                ),
                if (match.comment.isNotEmpty) // 自己紹介文を表示する。長すぎる場合は省略して2行まで表示。
                  Text(
                    match.comment,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: commentFontSize),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoto(BuildContext context) {
    final url = match.photoUrl;
    if (url == null) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(Icons.person, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Image.network(url, fit: BoxFit.cover);
  }
}
