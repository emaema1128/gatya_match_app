import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../network/bloom_api_client.dart';
import '../storage/device_id_provider.dart';
import '../storage/device_type_provider.dart';
import '../storage/token_storage.dart';
import 'auth_state.dart';
import 'sex.dart';

part 'auth_controller.g.dart';

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  FutureOr<AuthState> build() async {
    final tokenStorage = ref.watch(tokenStorageProvider);
    final token = await tokenStorage.readToken();
    if (token == null) return const Unauthenticated();

    // A present token only proves *something* was saved locally, not that
    // bloom still honors it. getUserData requires a valid token (route_api.php
    // checks it before dispatch), so calling it doubles as server-side
    // verification and hands back the systemId to hydrate state with.
    try {
      final data = await ref.read(bloomApiClientProvider).callApi('getUserData', {});
      final userData = data['user_data'] as Map<String, dynamic>;
      return Authenticated(systemId: _asInt(userData['system_id']));
    } catch (_) {
      await tokenStorage.clearSession();
      return const Unauthenticated();
    }
  }

  Future<void> logIn({required String loginId, required String password}) async {
    final data = await ref.read(bloomApiClientProvider).callApi('login', {
      'login_id': loginId,
      'password': password,
      'fcm_device_token': null,
    });
    await _completeSession(data['user_data'] as Map<String, dynamic>);
  }

  Future<void> register({
    required Sex sex,
    required String region,
    required String prefecture,
    required String city,
    required String comment,
  }) async {
    final apiClient = ref.read(bloomApiClientProvider);
    final deviceId = await ref.read(deviceIdProvider).resolve();
    final deviceType = ref.read(deviceTypeProvider);

    final existsData = await apiClient.callApi('existsDeviceId', {
      'device_id': deviceId,
      'adjust_id': null,
    });
    if (existsData['status'] == 'exists') {
      throw const DeviceAlreadyRegisteredException();
    }

    final data = await apiClient.callApi('registUser', {
      'device_type': deviceType,
      'device_id': deviceId,
      'adjust_id': null,
      'sex': sex.apiValue,
      'adcode': null,
      'region': _asInt(region),
      'prefecture': _asInt(prefecture),
      'city': _asInt(city),
      'comment': comment,
      'fcm_device_token': null,
    });
    await _completeSession(data['user_data'] as Map<String, dynamic>);
  }

  Future<void> logOut() async {
    await ref.read(tokenStorageProvider).clearSession();
    ref.invalidateSelf();
    await future;
  }

  /// Shared by [logIn] and [register] — both bloom responses carry the same
  /// `user_data` shape (system_id + app_access_token), and both need the
  /// same mandatory post-login housekeeping call before the session counts
  /// as active.
  Future<void> _completeSession(Map<String, dynamic> userData) async {
    final systemId = _asInt(userData['system_id']);
    final token = userData['app_access_token'] as String;

    final tokenStorage = ref.read(tokenStorageProvider);
    await tokenStorage.saveSession(token: token, systemId: systemId);

    try {
      // Mandatory post-login housekeeping call. Treated as part of the same
      // atomic login/registration operation: if it fails, undo the session
      // rather than leaving the user half-logged-in, and let the error
      // surface on the calling screen like any other failure.
      await ref.read(bloomApiClientProvider).callApi('verificationAfterLoginProcess', {});
    } catch (_) {
      await tokenStorage.clearSession();
      rethrow;
    }

    state = AsyncData(Authenticated(systemId: systemId));
  }
}

/// Thrown by [AuthController.register] when bloom's `existsDeviceId` reports
/// this device already has an account. Registration is blocked client-side
/// before `registUser` is ever called — this is a client policy decision,
/// not a [BloomApiException]: `existsDeviceId` itself always returns
/// `result: '1'`, it's just informational.
class DeviceAlreadyRegisteredException implements Exception {
  const DeviceAlreadyRegisteredException();
}

/// bloom's `getUserData` (called internally by both `login`/`registUser` and
/// the boot-time verification above) returns row values stringified, so
/// `system_id` can arrive as either a JSON number or a numeric string
/// depending on call site.
int _asInt(Object? value) => value is int ? value : int.parse(value.toString());
