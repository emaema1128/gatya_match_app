import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/bloom_api_client.dart';
import '../domain/match_data.dart';

part 'received_like_list_controller.g.dart';

/// 受け取った・未マッチのいいね一覧
/// ([gacha-redesign/issues/02](../../../../.scratch/gacha-redesign/issues/02-like-match-tab-split.md)
/// で決定した「いいね」タブ用)。マッチが成立すると`likes.status`が
/// `MATCH`に変わり`getReceivedLikeList`のWHERE句(`status IN (1,2)`)から
/// 自然に外れるため、追加のバックエンド実装なしで「マッチ」タブへの
/// 自動移動が実現できる。`STATUS_REJECT(4)`もこのWHERE句が最初から
/// 対象外にしているため、クライアント側でのフィルタは不要。
@riverpod
class ReceivedLikeListController extends _$ReceivedLikeListController {
  @override
  Future<List<MatchData>> build() async {
    final data = await ref.read(bloomApiClientProvider).callApi('getReceivedLikeList', {});
    final receivedLikeList = (data['received_like_list'] as List<dynamic>?) ?? const [];
    return receivedLikeList
        .cast<Map<String, dynamic>>()
        .map(MatchData.fromReceivedLikeEntry)
        .toList();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
