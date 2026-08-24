import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../network/bloom_api_client.dart';

part 'profile_option_list_provider.g.dart';

/// One entry from bloom's getAgeList/getIncomeList/getAddressList — all
/// three share this {id, item, sex} shape (a flat map, unlike getAreaList's
/// region/prefecture/city hierarchy). `sex` matches [Sex.apiValue]; callers
/// filter to the current user's own sex before presenting choices, since
/// bloom returns both sexes' options mixed together.
class ProfileOption {
  const ProfileOption({required this.id, required this.item, required this.sex});

  final String id;
  final String item;
  final String sex;

  factory ProfileOption.fromJson(String id, Map<String, dynamic> json, String itemKey) => ProfileOption(
        id: id,
        item: json[itemKey] as String,
        sex: json['sex'].toString(),
      );
}

List<ProfileOption> _parseOptionMap(Map<String, dynamic> raw, String itemKey) => raw.entries
    .map((entry) => ProfileOption.fromJson(entry.key, entry.value as Map<String, dynamic>, itemKey))
    .toList();

@Riverpod(keepAlive: true)
Future<List<ProfileOption>> ageOptionList(Ref ref) async {
  final data = await ref.watch(bloomApiClientProvider).callApi('getAgeList', {});
  return _parseOptionMap(data['age_list'] as Map<String, dynamic>, 'age_item');
}

@Riverpod(keepAlive: true)
Future<List<ProfileOption>> incomeOptionList(Ref ref) async {
  final data = await ref.watch(bloomApiClientProvider).callApi('getIncomeList', {});
  return _parseOptionMap(data['income_list'] as Map<String, dynamic>, 'income_item');
}

@Riverpod(keepAlive: true)
Future<List<ProfileOption>> addressOptionList(Ref ref) async {
  final data = await ref.watch(bloomApiClientProvider).callApi('getAddressList', {});
  return _parseOptionMap(data['address_list'] as Map<String, dynamic>, 'address_item');
}
