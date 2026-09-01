// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skipped_like_ids_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$skippedLikeIdsControllerHash() =>
    r'247b23500027f123a19246eb05956ff22dc7ee61';

/// 「いいね」タブで拒否(スキップ)した相手のsystem_idを保持する。
///
/// 拒否のサーバー永続化(`likes.status`を`STATUS_REJECT`にする処理)は
/// このリポジトリの外にあるバックエンド(`Class_Likes.php`、bloom本体側)の
/// 対応が必要なため未実装——このProviderはアプリ内メモリのみで拒否済みを
/// 一覧から隠す暫定実装で、アプリを再起動すると一覧に戻ってきてしまう。
/// バックエンド対応が整い次第、サーバー呼び出しに置き換える想定。
///
/// [ReceivedLikeListController]とは別Providerにしているのは、一覧の
/// 再取得(refresh/invalidate)があっても拒否済み一覧が消えないようにするため
/// (受信いいね一覧のプロバイダー自体を都度作り直すと、インスタンスに
/// 持たせた拒否済みセットも一緒にリセットされてしまう)。
///
/// Copied from [SkippedLikeIdsController].
@ProviderFor(SkippedLikeIdsController)
final skippedLikeIdsControllerProvider =
    AutoDisposeNotifierProvider<SkippedLikeIdsController, Set<int>>.internal(
      SkippedLikeIdsController.new,
      name: r'skippedLikeIdsControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$skippedLikeIdsControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SkippedLikeIdsController = AutoDisposeNotifier<Set<int>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
