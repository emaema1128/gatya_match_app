// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blocked_talk_ids_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$blockedTalkIdsControllerHash() =>
    r'73cb4a8aa1dc82981b06543871d420b72e165200';

/// チャット一覧でブロックした相手のtargetId(system_id)を保持する。
///
/// ブロックは`updateContactNg`でサーバーにも送信するが、
/// `getMailListForMatching`がNG済みの相手を実際に除外して返すかは未確認のため、
/// 除外されなかった場合でも一覧から即座に消えるよう、アプリ内メモリ側でも
/// 二重に隠す([SkippedLikeIdsController]と同じ考え方)。アプリを再起動すると
/// このメモリ上の記録は失われるが、サーバー側のNG登録が効いていれば
/// 再取得時にも一覧から除外され続ける想定。
///
/// [TalkListController]とは別Providerにしているのは、一覧の再取得
/// (refresh/invalidate)があってもブロック済み一覧が消えないようにするため。
///
/// Copied from [BlockedTalkIdsController].
@ProviderFor(BlockedTalkIdsController)
final blockedTalkIdsControllerProvider =
    AutoDisposeNotifierProvider<BlockedTalkIdsController, Set<int>>.internal(
      BlockedTalkIdsController.new,
      name: r'blockedTalkIdsControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$blockedTalkIdsControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BlockedTalkIdsController = AutoDisposeNotifier<Set<int>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
