// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'received_like_list_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$receivedLikeListControllerHash() =>
    r'c51ff635917c1be5153135d1406af00d86966c8a';

/// 受け取った・未マッチのいいね一覧
/// ([gacha-redesign/issues/02](../../../../.scratch/gacha-redesign/issues/02-like-match-tab-split.md)
/// で決定した「いいね」タブ用)。マッチが成立すると`likes.status`が
/// `MATCH`に変わり`getReceivedLikeList`のWHERE句(`status IN (1,2)`)から
/// 自然に外れるため、追加のバックエンド実装なしで「マッチ」タブへの
/// 自動移動が実現できる。`STATUS_REJECT(4)`もこのWHERE句が最初から
/// 対象外にしているため、クライアント側でのフィルタは不要。
///
/// Copied from [ReceivedLikeListController].
@ProviderFor(ReceivedLikeListController)
final receivedLikeListControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      ReceivedLikeListController,
      List<MatchData>
    >.internal(
      ReceivedLikeListController.new,
      name: r'receivedLikeListControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$receivedLikeListControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ReceivedLikeListController =
    AutoDisposeAsyncNotifier<List<MatchData>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
