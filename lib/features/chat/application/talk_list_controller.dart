import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/bloom_api_client.dart';
import '../domain/talk_summary.dart';

part 'talk_list_controller.g.dart';

@riverpod
class TalkListController extends _$TalkListController {
  @override
  Future<List<TalkSummary>> build() async {
    final data = await ref.read(bloomApiClientProvider).callApi('getMailListForMatching', {});
    final mailList = (data['mail_list'] as List<dynamic>?) ?? const [];
    return mailList.map((entry) => TalkSummary.fromMailListEntry(entry as Map<String, dynamic>)).toList();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// ボトムナビの「チャット」タブ・トーク一覧に表示する未読件数の合計。
@riverpod
int totalUnreadChatCount(Ref ref) {
  final talks = ref.watch(talkListControllerProvider).value;
  if (talks == null) return 0;
  return talks.fold<int>(0, (sum, talk) => sum + talk.unreadCount);
}
