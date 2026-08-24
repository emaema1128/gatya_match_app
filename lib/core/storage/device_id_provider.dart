import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_id_provider.g.dart';

/// Resolves bloom's `existsDeviceId` `device_id` param to a real per-device
/// identifier — iOS's `identifierForVendor`, Android's `Settings.Secure.ANDROID_ID`
/// (via the dedicated `android_id` plugin; `device_info_plus` doesn't expose
/// it — its Android fields describe the OS build, not the device instance).
/// The OS hands back the same value every time, so nothing is cached here.
class DeviceIdProvider {
  Future<String> resolve() async {
    if (Platform.isIOS) {
      final plugin = DeviceInfoPlugin();
      var id = (await plugin.iosInfo).identifierForVendor;
      // Apple: identifierForVendor can be nil right after a device restart,
      // before the user has unlocked it once — wait briefly and retry once.
      id ??= await Future.delayed(
        const Duration(milliseconds: 500),
        () async => (await plugin.iosInfo).identifierForVendor,
      );
      if (id == null) throw const DeviceIdUnavailableException();
      return id;
    }
    if (Platform.isAndroid) {
      final id = await const AndroidId().getId();
      if (id == null) throw const DeviceIdUnavailableException();
      return id;
    }
    throw UnsupportedError('device_id is only supported on iOS and Android');
  }
}

/// Thrown when the platform's device identifier couldn't be resolved (e.g.
/// iOS identifierForVendor still nil after the retry). Caught by
/// registration_screen.dart to show a friendly retry message.
class DeviceIdUnavailableException implements Exception {
  const DeviceIdUnavailableException();
}

@Riverpod(keepAlive: true)
DeviceIdProvider deviceId(Ref ref) => DeviceIdProvider();
