import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/bloom_api_client.dart';
import '../domain/match_data.dart';

part 'match_list_controller.g.dart';

@riverpod
class MatchListController extends _$MatchListController {
  @override
  Future<List<MatchData>> build() async {
    final data = await ref.read(bloomApiClientProvider).callApi('getMatchList', {});
    final matchList = (data['match_list'] as List<dynamic>?) ?? const [];
    return matchList.map((entry) => MatchData.fromMatchListEntry(entry as Map<String, dynamic>)).toList();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
