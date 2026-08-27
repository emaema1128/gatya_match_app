import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import 'app_routes.dart';
import 'router_refresh_notifier.dart';

part 'app_router.g.dart';


@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refreshNotifier = RouterRefreshNotifier(ref);// authControllerProviderの状態変化を監視して、リダイレクトロジックを再評価するためのChangeNotifier
  ref.onDispose(refreshNotifier.dispose);
  // GoRouterのインスタンスを作成し、ルート定義、リフレッシュ通知、リダイレクトロジックを設定
  return GoRouter(
    initialLocation: const SplashRoute().location,// 初期画面をスプラッシュ画面に設定
    routes: $appRoutes,// ルート定義を設定
    refreshListenable: refreshNotifier,// authControllerProviderの状態変化を監視して、リダイレクトロジックを再評価するためのChangeNotifier
    redirect: (context, state) => _redirect(ref, state),// 認証状態と現在の画面に基づいてリダイレクト先を決定するロジック
  );
}

// 今のログイン状態と、今いる画面の状態を見て、どの画面に遷移するかを決める
String? _redirect(Ref ref, GoRouterState state) {
  final authState = ref.read(authControllerProvider);
  final isSplash = state.matchedLocation == const SplashRoute().location;
  final isWelcome = state.matchedLocation == const WelcomeRoute().location;
  final isLoggingIn = state.matchedLocation == const LoginRoute().location;
  final isRegistering = state.matchedLocation == const RegistrationRoute().location;
  // 認証済みになった時に自動でホームへ送る対象からは登録画面を除く
  // (isAuthScreen)。登録画面は成功後にプロフィール入力画面へ明示的に遷移する
  // ため(RegistrationScreen参照)、ここでホームへ先取りして送ってしまうと競合する。
  // 未ログイン時にアクセスを許可する画面(isPublicScreen)には引き続き含める。
  final isAuthScreen = isWelcome || isLoggingIn;
  final isPublicScreen = isAuthScreen || isRegistering;

  return switch (authState) {
    AsyncData(:final value) => switch (value) {
      Authenticated() => (isAuthScreen || isSplash) ? const HomeTabRoute().location : null,
      Unauthenticated() => isPublicScreen ? null : const WelcomeRoute().location,
    },
    AsyncError() => isPublicScreen ? null : const WelcomeRoute().location,
    _ => isSplash ? null : const SplashRoute().location,
  };
}
