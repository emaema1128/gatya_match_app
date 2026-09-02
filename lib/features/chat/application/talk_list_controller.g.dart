// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'talk_list_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$totalUnreadChatCountHash() =>
    r'3197dbaa3698ee39365cad8c82a34356ec6ac48b';

/// ボトムナビの「チャット」タブ・トーク一覧に表示する未読件数の合計。
///
/// Copied from [totalUnreadChatCount].
@ProviderFor(totalUnreadChatCount)
final totalUnreadChatCountProvider = AutoDisposeProvider<int>.internal(
  totalUnreadChatCount,
  name: r'totalUnreadChatCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$totalUnreadChatCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TotalUnreadChatCountRef = AutoDisposeProviderRef<int>;
String _$talkListControllerHash() =>
    r'7e25469633f554bb858f8ccbcbc4d56b46d832b4';

/// See also [TalkListController].
@ProviderFor(TalkListController)
final talkListControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      TalkListController,
      List<TalkSummary>
    >.internal(
      TalkListController.new,
      name: r'talkListControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$talkListControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TalkListController = AutoDisposeAsyncNotifier<List<TalkSummary>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
