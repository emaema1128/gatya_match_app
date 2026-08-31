import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/bloom_api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../application/talk_list_controller.dart';
import '../domain/talk_summary.dart';

/// トーク一覧画面(チャットタブの中身)。マッチした相手ごとに1行、
/// 直近のメッセージ・未読件数を表示する([stage5-chat](../../../../.scratch/stage5-chat/map.md)で決定)。
class ChatTabScreen extends ConsumerWidget {
  const ChatTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final talksAsync = ref.watch(talkListControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('チャット')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(talkListControllerProvider.notifier).refresh(),
          child: talksAsync.when(
            data: (talks) => talks.isEmpty ? _buildEmptyState(context) : _buildList(context, talks),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _buildErrorState(context, error),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<TalkSummary> talks) {
    return ListView.separated(
      itemCount: talks.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildTalkRow(context, talks[index]),
    );
  }

  Widget _buildTalkRow(BuildContext context, TalkSummary talk) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: talk.photoUrl != null ? NetworkImage(talk.photoUrl!) : null,
        child: talk.photoUrl == null ? const Icon(Icons.person_outline) : null,
      ),
      title: Text(talk.targetName),
      subtitle: Text(
        talk.lastMessage.isEmpty ? 'まだメッセージがありません' : talk.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(talk.lastMessageAt, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          if (talk.unreadCount > 0) Badge(label: Text('${talk.unreadCount}')),
        ],
      ),
      onTap: () => ChatThreadRoute(partnerId: talk.targetId).push(context),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'まだトークがありません。マッチが成立するとここに表示されます。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final message = error is BloomApiException ? error.errorDetail : '通信状態を確認してください。';
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ),
      ),
    );
  }
}
