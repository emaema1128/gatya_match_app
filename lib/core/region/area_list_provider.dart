import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../network/bloom_api_client.dart';

part 'area_list_provider.g.dart';

/// One entry from bloom's `getAreaList` `area_list` map.
/// lv:1 = region, lv:2 = prefecture, lv:3 = city.
class Area {
  const Area({required this.id, required this.level, required this.parentId, required this.name});

  final String id;
  final int level;
  final String? parentId;
  final String name;

  factory Area.fromJson(String id, Map<String, dynamic> json) => Area(
        id: id,
        level: json['lv'] as int,
        // `parent` arrives as a JSON number (or null); normalize to String so
        // it can be compared against Area.id directly.
        parentId: json['parent']?.toString(),
        name: json['name'] as String,
      );
}

/// Wraps bloom's flat `area_list` map (~1000 entries) with lv/parent lookups
/// for building a region → prefecture → city cascade.
class AreaList {
  AreaList._(this._childrenByParent);

  static const _kRootKey = '__root__';

  final Map<String, List<Area>> _childrenByParent;

  factory AreaList.fromJson(Map<String, dynamic> areaListJson) {
    final childrenByParent = <String, List<Area>>{};
    final regions = <Area>[];

    areaListJson.forEach((id, value) {
      // "" is the lv:1 "All" placeholder row — not a selectable option.
      if (id.isEmpty) return;
      final area = Area.fromJson(id, value as Map<String, dynamic>);
      if (area.level == 1) regions.add(area);
      if (area.parentId != null) {
        childrenByParent.putIfAbsent(area.parentId!, () => []).add(area);
      }
    });

    childrenByParent[_kRootKey] = regions;
    return AreaList._(childrenByParent);
  }

  /// lv:1 (region) options, in the order bloom returns them.
  List<Area> get regions => _childrenByParent[_kRootKey] ?? const [];

  List<Area> prefecturesOf(String regionId) => _childrenByParent[regionId] ?? const [];

  List<Area> citiesOf(String prefectureId) => _childrenByParent[prefectureId] ?? const [];
}

@Riverpod(keepAlive: true)
Future<AreaList> areaList(Ref ref) async {
  final data = await ref.watch(bloomApiClientProvider).callApi('getAreaList', {});
  return AreaList.fromJson(data['area_list'] as Map<String, dynamic>);
}
