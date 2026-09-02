// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $splashRoute,
  $welcomeRoute,
  $loginRoute,
  $registrationRoute,
  $profileRoute,
  $myProfileRoute,
  $settingsRoute,
  $matchCelebrationRoute,
  $receivedLikeDetailRoute,
  $chatThreadRoute,
  $gachaRevealRoute,
  $homeShellRouteData,
];

RouteBase get $splashRoute =>
    GoRouteData.$route(path: '/', factory: _$SplashRoute._fromState);

mixin _$SplashRoute on GoRouteData {
  static SplashRoute _fromState(GoRouterState state) => const SplashRoute();

  @override
  String get location => GoRouteData.$location('/');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $welcomeRoute =>
    GoRouteData.$route(path: '/welcome', factory: _$WelcomeRoute._fromState);

mixin _$WelcomeRoute on GoRouteData {
  static WelcomeRoute _fromState(GoRouterState state) => const WelcomeRoute();

  @override
  String get location => GoRouteData.$location('/welcome');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $loginRoute =>
    GoRouteData.$route(path: '/login', factory: _$LoginRoute._fromState);

mixin _$LoginRoute on GoRouteData {
  static LoginRoute _fromState(GoRouterState state) => const LoginRoute();

  @override
  String get location => GoRouteData.$location('/login');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $registrationRoute => GoRouteData.$route(
  path: '/registration',

  factory: _$RegistrationRoute._fromState,
);

mixin _$RegistrationRoute on GoRouteData {
  static RegistrationRoute _fromState(GoRouterState state) =>
      const RegistrationRoute();

  @override
  String get location => GoRouteData.$location('/registration');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $profileRoute =>
    GoRouteData.$route(path: '/profile', factory: _$ProfileRoute._fromState);

mixin _$ProfileRoute on GoRouteData {
  static ProfileRoute _fromState(GoRouterState state) => const ProfileRoute();

  @override
  String get location => GoRouteData.$location('/profile');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $myProfileRoute => GoRouteData.$route(
  path: '/mypage/profile',

  factory: _$MyProfileRoute._fromState,
);

mixin _$MyProfileRoute on GoRouteData {
  static MyProfileRoute _fromState(GoRouterState state) =>
      const MyProfileRoute();

  @override
  String get location => GoRouteData.$location('/mypage/profile');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $settingsRoute => GoRouteData.$route(
  path: '/mypage/settings',

  factory: _$SettingsRoute._fromState,
);

mixin _$SettingsRoute on GoRouteData {
  static SettingsRoute _fromState(GoRouterState state) => const SettingsRoute();

  @override
  String get location => GoRouteData.$location('/mypage/settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $matchCelebrationRoute => GoRouteData.$route(
  path: '/matches/celebration/:matchedSystemId',

  factory: _$MatchCelebrationRoute._fromState,
);

mixin _$MatchCelebrationRoute on GoRouteData {
  static MatchCelebrationRoute _fromState(GoRouterState state) =>
      MatchCelebrationRoute(
        matchedSystemId: int.parse(state.pathParameters['matchedSystemId']!)!,
      );

  MatchCelebrationRoute get _self => this as MatchCelebrationRoute;

  @override
  String get location => GoRouteData.$location(
    '/matches/celebration/${Uri.encodeComponent(_self.matchedSystemId.toString())}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $receivedLikeDetailRoute => GoRouteData.$route(
  path: '/matches/received-like/:systemId',

  factory: _$ReceivedLikeDetailRoute._fromState,
);

mixin _$ReceivedLikeDetailRoute on GoRouteData {
  static ReceivedLikeDetailRoute _fromState(GoRouterState state) =>
      ReceivedLikeDetailRoute(
        systemId: int.parse(state.pathParameters['systemId']!)!,
      );

  ReceivedLikeDetailRoute get _self => this as ReceivedLikeDetailRoute;

  @override
  String get location => GoRouteData.$location(
    '/matches/received-like/${Uri.encodeComponent(_self.systemId.toString())}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $chatThreadRoute => GoRouteData.$route(
  path: '/chat/thread/:partnerId',

  factory: _$ChatThreadRoute._fromState,
);

mixin _$ChatThreadRoute on GoRouteData {
  static ChatThreadRoute _fromState(GoRouterState state) => ChatThreadRoute(
    partnerId: int.parse(state.pathParameters['partnerId']!)!,
  );

  ChatThreadRoute get _self => this as ChatThreadRoute;

  @override
  String get location => GoRouteData.$location(
    '/chat/thread/${Uri.encodeComponent(_self.partnerId.toString())}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $gachaRevealRoute => GoRouteData.$route(
  path: '/gacha/reveal',

  factory: _$GachaRevealRoute._fromState,
);

mixin _$GachaRevealRoute on GoRouteData {
  static GachaRevealRoute _fromState(GoRouterState state) =>
      const GachaRevealRoute();

  @override
  String get location => GoRouteData.$location('/gacha/reveal');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $homeShellRouteData => StatefulShellRouteData.$route(
  factory: $HomeShellRouteDataExtension._fromState,
  branches: [
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(path: '/home', factory: _$HomeTabRoute._fromState),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/matches',

          factory: _$MatchesTabRoute._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(path: '/chat', factory: _$ChatTabRoute._fromState),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/mypage',

          factory: _$ProfileTabRoute._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/points',

          factory: _$PointsTabRoute._fromState,
        ),
      ],
    ),
  ],
);

extension $HomeShellRouteDataExtension on HomeShellRouteData {
  static HomeShellRouteData _fromState(GoRouterState state) =>
      const HomeShellRouteData();
}

mixin _$HomeTabRoute on GoRouteData {
  static HomeTabRoute _fromState(GoRouterState state) => const HomeTabRoute();

  @override
  String get location => GoRouteData.$location('/home');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$MatchesTabRoute on GoRouteData {
  static MatchesTabRoute _fromState(GoRouterState state) =>
      const MatchesTabRoute();

  @override
  String get location => GoRouteData.$location('/matches');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$ChatTabRoute on GoRouteData {
  static ChatTabRoute _fromState(GoRouterState state) => const ChatTabRoute();

  @override
  String get location => GoRouteData.$location('/chat');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$ProfileTabRoute on GoRouteData {
  static ProfileTabRoute _fromState(GoRouterState state) =>
      const ProfileTabRoute();

  @override
  String get location => GoRouteData.$location('/mypage');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$PointsTabRoute on GoRouteData {
  static PointsTabRoute _fromState(GoRouterState state) =>
      const PointsTabRoute();

  @override
  String get location => GoRouteData.$location('/points');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
