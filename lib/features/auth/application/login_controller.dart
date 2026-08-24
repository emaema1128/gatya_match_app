import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/auth/auth_controller.dart';

part 'login_controller.g.dart';

@riverpod
class LoginController extends _$LoginController {
  @override
  FutureOr<void> build() {}

  Future<void> submit({required String loginId, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authControllerProvider.notifier).logIn(loginId: loginId, password: password),
    );
  }
}
