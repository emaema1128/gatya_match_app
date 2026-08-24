import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_type_provider.g.dart';

/// Resolves bloom's `registUser` `device_type` param. Unlike [deviceIdProvider],
/// this is a pure platform check with no async plugin call, so it's a plain
/// value provider rather than a class with a `resolve()` method.
@Riverpod(keepAlive: true)
String deviceType(Ref ref) {
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  throw UnsupportedError('device_type is only supported on iOS and Android');
}
