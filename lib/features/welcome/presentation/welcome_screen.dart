import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';

/// 未ログインユーザーの入口画面。新規登録とログインの選択肢を提示する。
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 50),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Text(
                'Gatya App',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => const RegistrationRoute().push(context),
                  child: const Text('新規登録の方はこちら'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => const LoginRoute().push(context),
                  child: const Text('ログイン'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

