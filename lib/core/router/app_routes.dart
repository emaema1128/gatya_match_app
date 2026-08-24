import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/registration_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/home/presentation/home_shell_screen.dart';
import '../../features/home/presentation/home_tab_screen.dart';
import '../../features/home/presentation/settings_tab_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/welcome/presentation/welcome_screen.dart';

part 'app_routes.g.dart';

// ルートの定義
@TypedGoRoute<SplashRoute>(path: '/')
class SplashRoute extends GoRouteData with _$SplashRoute {
  const SplashRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SplashScreen();
}

// ようこそ画面のルートを追加（未ログイン時の入口）
@TypedGoRoute<WelcomeRoute>(path: '/welcome')
class WelcomeRoute extends GoRouteData with _$WelcomeRoute {
  const WelcomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const WelcomeScreen();
}

// ログイン画面のルートを追加
@TypedGoRoute<LoginRoute>(path: '/login')
class LoginRoute extends GoRouteData with _$LoginRoute {
  const LoginRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const LoginScreen();
}

// 新規登録画面のルートを追加
@TypedGoRoute<RegistrationRoute>(path: '/registration')
class RegistrationRoute extends GoRouteData with _$RegistrationRoute {
  const RegistrationRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const RegistrationScreen();
}

// プロフィール作成/編集画面のルートを追加(新規登録直後の任意ステップ、マイページからの編集の両方で使う)
@TypedGoRoute<ProfileRoute>(path: '/profile')
class ProfileRoute extends GoRouteData with _$ProfileRoute {
  const ProfileRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const ProfileScreen();
}

// ホーム画面のシェルルートを追加
@TypedStatefulShellRoute<HomeShellRouteData>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<HomeBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<HomeTabRoute>(path: '/home'),
      ],
    ),
    TypedStatefulShellBranch<SettingsBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<SettingsTabRoute>(path: '/settings'),
      ],
    ),
  ],
)
class HomeShellRouteData extends StatefulShellRouteData {
  const HomeShellRouteData();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) => HomeShellScreen(navigationShell: navigationShell);
}

// ホーム画面のブランチデータを定義
class HomeBranchData extends StatefulShellBranchData {
  const HomeBranchData();
}

// 設定画面のブランチデータを定義
class SettingsBranchData extends StatefulShellBranchData {
  const SettingsBranchData();
}

// ホームタブのルートを追加
class HomeTabRoute extends GoRouteData with _$HomeTabRoute {
  const HomeTabRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeTabScreen();
}

// 設定タブのルートを追加
class SettingsTabRoute extends GoRouteData with _$SettingsTabRoute {
  const SettingsTabRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SettingsTabScreen();
}
