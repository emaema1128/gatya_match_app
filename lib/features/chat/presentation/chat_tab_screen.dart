import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../core/network/bloom_api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../application/blocked_talk_ids_controller.dart';
import '../application/talk_list_controller.dart';
import '../domain/talk_summary.dart';

/// トーク一覧画面(チャットタブの中身)。マッチした相手ごとに1行、
/// 直近のメッセージ・未読件数を表示する([stage5-chat](../../../../.scratch/stage5-chat/map.md)で決定)。
class ChatTabScreen extends ConsumerWidget {
  const ChatTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final talksAsync = ref.watch(talkListControllerProvider);
    // この場でブロックした相手のtargetId。サーバーのNG登録が一覧から確実に
    // 除外してくれるかは未確認のため、ローカルでも一覧から隠す
    // ([BlockedTalkIdsController]参照)。
    final blockedIds = ref.watch(blockedTalkIdsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('チャット')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(talkListControllerProvider.notifier).refresh(),
          child: talksAsync.when(
            data: (talks) {
              final visibleTalks = talks.where((talk) => !blockedIds.contains(talk.targetId)).toList();
              return visibleTalks.isEmpty
                  ? _buildEmptyState(context)
                  : _buildList(context, ref, visibleTalks);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _buildErrorState(context, error),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<TalkSummary> talks) {
    // SlidableAutoCloseBehaviorで囲むことで、いずれかの行を開いたときに
    // 他の開いている行を自動で閉じる(排他制御)。flutter_slidableはこの
    // ウィジェットで明示的に囲まない限り排他制御が効かない仕様のため必須。
    return SlidableAutoCloseBehavior(
      child: ListView.separated(
        itemCount: talks.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => _buildTalkRow(context, ref, talks[index]),
      ),
    );
  }

  // targetIdをkeyにしているのは、ListViewがスクロール中にWidgetを使い回すため。
  // keyが無い(または不安定な)と、スワイプで開いた状態が別の行に飛び移ってしまう。
  Widget _buildTalkRow(BuildContext context, WidgetRef ref, TalkSummary talk) {
    return Slidable(
      key: ValueKey(talk.targetId),
      // 右から左にスワイプしたときに現れるアクション(endActionPane)として、
      // ブロックボタンを1つだけ配置する。
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            // SlidableActionはタップされると自動でアクションパネルを閉じるため、
            // このコールバックが渡してくるcontext(パネル自身のcontext)は
            // 閉じるアニメーションと共にすぐ破棄されてしまう。確認ダイアログの
            // 結果を待つ間もmountedであり続ける、行(ListTile)側の安定した
            // contextを使う必要があるため、あえて外側の`context`を使う。
            onPressed: (_) => _onBlockPressed(context, ref, talk),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            icon: Icons.block,
            label: 'ブロック',
          ),
        ],
      ),
      child: ListTile(
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
      ),
    );
  }

  // ブロックボタン押下時の処理。確認アラートを出し、「ブロック」が選ばれたら
  // サーバーにNG登録(updateContactNg)し、成功したらローカルの一覧からも隠す。
  Future<void> _onBlockPressed(BuildContext context, WidgetRef ref, TalkSummary talk) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ブロックしますか？'),
        content: Text('${talk.targetName}さんをブロックすると、トークができなくなります。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('ブロック', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    // showDialogはFutureを返す(=await中に画面が破棄される可能性がある)ため、
    // 再開後にcontextを使う前にmountedを確認する。
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(talkListControllerProvider.notifier).block(talk.targetId);
      ref.read(blockedTalkIdsControllerProvider.notifier).add(talk.targetId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${talk.targetName}さんをブロックしました')));
    } catch (error) {
      if (!context.mounted) return;
      final message = error is BloomApiException ? error.errorDetail : '通信状態を確認してください。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
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
