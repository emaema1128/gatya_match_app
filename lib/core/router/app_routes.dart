import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/registration_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/chat/presentation/chat_tab_screen.dart';
import '../../features/chat/presentation/chat_thread_screen.dart';
import '../../features/gacha/presentation/gacha_reveal_screen.dart';
import '../../features/home/presentation/home_shell_screen.dart';
import '../../features/home/presentation/home_tab_screen.dart';
import '../../features/matches/presentation/match_celebration_screen.dart';
import '../../features/matches/presentation/match_list_screen.dart';
import '../../features/point/presentation/points_tab_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/welcome/presentation/welcome_screen.dart';

part 'app_routes.g.dart';

// アプリの全ルート(画面遷移先)定義。
//
// go_router_builder方式(型安全なルート定義)を採用している:
// 「1画面 = 1つの`XxxRoute`クラス」を`@TypedGoRoute<XxxRoute>(path: '...')`で
// 宣言すると、`dart run build_runner build`がこのファイルを解析して
// `part 'app_routes.g.dart'`に`_$XxxRoute`のようなmixinを自動生成する。
// これにより文字列のURLを直接書かずに、`const XxxRoute().go(context)`(画面遷移)や
// `XxxRoute().location`(URL文字列)のような型安全な呼び出しができるようになる。
//
// ルートには大きく2種類ある:
// - 単純なフルスクリーンのルート(`GoRouteData`を継承): 画面全体を差し替える。
// - ボトムナビ付きのシェルルート(`StatefulShellRouteData`/`StatefulShellBranchData`):
//   下記の`HomeShellRouteData`のように、タブを切り替えても各タブのナビゲーション
//   履歴やスクロール位置などの状態を保持したまま表示を切り替える。
//   ボトムナビ本体(`NavigationBar`)は
//   [home_shell_screen.dart](../../features/home/presentation/home_shell_screen.dart)側にある。

// ============================================================
// 認証・起動フロー(未ログイン時にも表示できる画面)
// ============================================================

// 起動直後のスプラッシュ画面(ログイン状態を確認している間だけ表示)
@TypedGoRoute<SplashRoute>(path: '/')
class SplashRoute extends GoRouteData with _$SplashRoute {
  const SplashRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SplashScreen();
}

// ようこそ画面(未ログイン時の入口。ログイン/新規登録への導線)
@TypedGoRoute<WelcomeRoute>(path: '/welcome')
class WelcomeRoute extends GoRouteData with _$WelcomeRoute {
  const WelcomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const WelcomeScreen();
}

// ログイン画面
@TypedGoRoute<LoginRoute>(path: '/login')
class LoginRoute extends GoRouteData with _$LoginRoute {
  const LoginRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const LoginScreen();
}

// 新規登録画面
@TypedGoRoute<RegistrationRoute>(path: '/registration')
class RegistrationRoute extends GoRouteData with _$RegistrationRoute {
  const RegistrationRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const RegistrationScreen();
}

// ============================================================
// シェルの外に単独で存在するルート(ボトムナビには属さない)
// ============================================================
// 以下はいずれも「フルスクリーンで前面に重ねて表示し、閉じたら元のタブに戻る」画面。
// 下のボトムナビ5タブ(TypedStatefulShellRoute)には含まれない。

// プロフィール作成画面(新規登録直後の任意ステップ)。
// マイページタブから編集する場合は下の`ProfileTabRoute`(ブランチのルート画面)を使う——
// こちらは`isOnboarding: true`で開き、「あとで設定する」ボタンや保存後のホーム自動遷移が
// 有効になる点だけが違う(同じ`ProfileScreen`を再利用している)。
@TypedGoRoute<ProfileRoute>(path: '/profile')
class ProfileRoute extends GoRouteData with _$ProfileRoute {
  const ProfileRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const ProfileScreen(isOnboarding: true);
}

// 設定画面(ログアウト等)。マイページタブ(ProfileScreen)の歯車アイコンからpushされる。
@TypedGoRoute<SettingsRoute>(path: '/mypage/settings')
class SettingsRoute extends GoRouteData with _$SettingsRoute {
  const SettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SettingsScreen();
}

// マッチが成立した直後の演出画面
@TypedGoRoute<MatchCelebrationRoute>(path: '/matches/celebration/:matchedSystemId')
class MatchCelebrationRoute extends GoRouteData with _$MatchCelebrationRoute {
  const MatchCelebrationRoute({required this.matchedSystemId});

  final int matchedSystemId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      MatchCelebrationScreen(matchedSystemId: matchedSystemId);
}

// チャットの個別スレッド画面
@TypedGoRoute<ChatThreadRoute>(path: '/chat/thread/:partnerId')
class ChatThreadRoute extends GoRouteData with _$ChatThreadRoute {
  const ChatThreadRoute({required this.partnerId});

  final int partnerId;

  @override
  Widget build(BuildContext context, GoRouterState state) => ChatThreadScreen(partnerId: partnerId);
}

// ガチャ排出結果(スワイプカード)画面。
// 候補は都度URLに乗せず、gachaControllerProviderの直近のスピン結果を読む
// (MatchCelebrationRouteがmatchListControllerProviderを読む方式と同じ)。
@TypedGoRoute<GachaRevealRoute>(path: '/gacha/reveal')
class GachaRevealRoute extends GoRouteData with _$GachaRevealRoute {
  const GachaRevealRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const GachaRevealScreen();
}

// ============================================================
// ボトムナビ(シェルルート)の定義
// ============================================================
// `branches`の並び順が、ボトムナビ本体
// ([home_shell_screen.dart](../../features/home/presentation/home_shell_screen.dart)の
// `destinations`)の並び順と、0始まりのindexで対応している
// (branches[0]=Home, branches[1]=Matches, ... branches[4]=Points)。
// **この2つの並び順は必ず一致させること**——片方だけ並び替えると、
// タブのアイコン/ラベルと実際に表示される画面がズレる。

// ホーム画面のシェルルート(ボトムナビ本体)
@TypedStatefulShellRoute<HomeShellRouteData>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<HomeBranchData>( // index 0: ホーム(ガチャ)
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<HomeTabRoute>(path: '/home'),
      ],
    ),
    TypedStatefulShellBranch<MatchesBranchData>( // index 1: マッチ一覧(いいね/マッチ)
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<MatchesTabRoute>(path: '/matches'),
      ],
    ),
    TypedStatefulShellBranch<ChatBranchData>( // index 2: チャット
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<ChatTabRoute>(path: '/chat'),
      ],
    ),
    TypedStatefulShellBranch<ProfileBranchData>( // index 3: マイページ(プロフィール)
      routes: <TypedRoute<RouteData>>[
        // 上の独立`ProfileRoute`(/profile)とはpathが競合するため、
        // ブランチのルートは/mypageにしている(URL自体はどこにも表示されない)。
        TypedGoRoute<ProfileTabRoute>(path: '/mypage'),
      ],
    ),
    TypedStatefulShellBranch<PointsBranchData>( // index 4: ポイント
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<PointsTabRoute>(path: '/points'),
      ],
    ),
  ],
)
// シェル自体のルートデータ。builder()が返す`HomeShellScreen`が、
// ボトムナビ(NavigationBar)と選択中タブの中身(navigationShell)を組み立てる。
class HomeShellRouteData extends StatefulShellRouteData {
  const HomeShellRouteData();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) {
    return HomeShellScreen(navigationShell: navigationShell);
  }
}

// 各ブランチの「データ」クラス。ジェネリクスの型引数として使われるだけで、
// 中身(フィールド)は今のところ空でよい。
class HomeBranchData extends StatefulShellBranchData {
  const HomeBranchData();
}

class MatchesBranchData extends StatefulShellBranchData {
  const MatchesBranchData();
}

class ChatBranchData extends StatefulShellBranchData {
  const ChatBranchData();
}

class ProfileBranchData extends StatefulShellBranchData {
  const ProfileBranchData();
}

class PointsBranchData extends StatefulShellBranchData {
  const PointsBranchData();
}

// ============================================================
// 各タブが実際に表示する画面のルート
// ============================================================
// 上の`branches`から参照されている、タブ1つぶんの中身。
// 上のbranchesと同じ並び順(Home→Matches→Chat→Profile→Points)にしてある。

// ホームタブ(ガチャ画面)
class HomeTabRoute extends GoRouteData with _$HomeTabRoute {
  const HomeTabRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeTabScreen();
}

// マッチ一覧タブ(いいね/マッチ)
class MatchesTabRoute extends GoRouteData with _$MatchesTabRoute {
  const MatchesTabRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const MatchListScreen();
}

// チャットタブ
class ChatTabRoute extends GoRouteData with _$ChatTabRoute {
  const ChatTabRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const ChatTabScreen();
}

// プロフィールタブ(マイページ)
class ProfileTabRoute extends GoRouteData with _$ProfileTabRoute {
  const ProfileTabRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const ProfileScreen();
}

// ポイントタブ
class PointsTabRoute extends GoRouteData with _$PointsTabRoute {
  const PointsTabRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const PointsTabScreen();
}
