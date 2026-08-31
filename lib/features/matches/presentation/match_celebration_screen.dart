import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_routes.dart';
import '../application/match_list_controller.dart';
import '../domain/match_data.dart';
import 'match_profile_card.dart';

/// 「マッチしました!」演出画面
/// ([stage4-match-celebration](../../../../.scratch/stage4-match-celebration/map.md)で決定)。
///
/// 対象は「自分の操作でその場でマッチが成立したケース」のみ(`sendLike`の
/// レスポンスが`status: 'match'`を返した直後)——相手が後から
/// いいねを返す非同期のケースの検知はStage6(プッシュ通知)に委ねる。
/// `sendLike`のレスポンス自体には相手のプロフィール情報が含まれないため、
/// [matchListControllerProvider]から`matchedSystemId`に一致する1件を探して表示する。
///
/// **未接続**: このルートを実際に呼び出す処理(ガチャでいいねした結果が
/// マッチだった時に、この画面へ遷移させる)はStage3(ガチャ)の実装時に追加する。
/// 現時点ではURLから直接遷移した場合のみ動作を確認できる。
class MatchCelebrationScreen extends ConsumerWidget {
  const MatchCelebrationScreen({super.key, required this.matchedSystemId});

  final int matchedSystemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchListControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('マッチしました!')),
      body: SafeArea(
        child: matchesAsync.when(
          data: (matches) {
            final matching = matches.where((m) => m.systemId == matchedSystemId);
            final match = matching.isEmpty ? null : matching.first;
            if (match == null) {
              return const Center(child: Text('お相手の情報を取得できませんでした。'));
            }
            return _buildCelebration(context, match);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('お相手の情報を取得できませんでした。')),
        ),
      ),
    );
  }

  Widget _buildCelebration(BuildContext context, MatchData match) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: Opacity(opacity: value.clamp(0, 1), child: child),
            ),
            child: Text(
              'マッチしました!',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          MatchProfileCard(match: match),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => const MatchesTabRoute().go(context),
            child: const Text('マッチ一覧を見る'),
          ),
        ],
      ),
    );
  }
}
