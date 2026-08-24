import 'package:flutter/material.dart';

/// The router's redirect handles all navigation while the auth token is
/// being checked, so this screen has nothing state-dependent to render.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}
