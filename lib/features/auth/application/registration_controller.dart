import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/sex.dart';

part 'registration_controller.g.dart';

@riverpod
class RegistrationController extends _$RegistrationController {
  @override
  FutureOr<void> build() {}

  Future<void> submit({
    required Sex sex,
    required String region,
    required String prefecture,
    required String city,
    required String comment,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authControllerProvider.notifier).register(
            sex: sex,
            region: region,
            prefecture: prefecture,
            city: city,
            comment: comment,
          ),
    );
  }
}
