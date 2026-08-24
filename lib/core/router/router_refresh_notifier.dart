import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// Bridges Riverpod's [authControllerProvider] to go_router's
/// `refreshListenable`, so the router re-evaluates `redirect` whenever auth
/// state changes (not just on navigation).
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}
