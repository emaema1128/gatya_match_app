sealed class AuthState {
  const AuthState();
}

final class Authenticated extends AuthState {
  const Authenticated({required this.systemId});

  final int systemId;
}

final class Unauthenticated extends AuthState {
  const Unauthenticated();
}
