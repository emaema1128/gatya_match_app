import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/bloom_api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../application/login_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loginIdController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _loginIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onFieldChanged() => setState(() {});

  bool get _canSubmit =>
      _loginIdController.text.isNotEmpty && _passwordController.text.isNotEmpty;

  void _submit() {
    ref.read(loginControllerProvider.notifier).submit(
          loginId: _loginIdController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ログイン')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ログインID入力フィールド
            TextField(
              controller: _loginIdController,
              enabled: !loginState.isLoading,
              decoration: const InputDecoration(labelText: 'ログインID'),
            ),

            // パスワード入力フィールド
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              enabled: !loginState.isLoading,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'パスワード'),
            ),

            // ログインボタン
            const SizedBox(height: 24),
            if (loginState.isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                child: const Text('ログイン'),
              ),
            if (loginState.hasError) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage(loginState.error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],

            // // TODO: 新規登録画面のルートが決まったら差し替える
            // const SizedBox(height: 24),
            // TextButton(
            //   onPressed: loginState.isLoading ? null : () => const RegistrationRoute().push(context),
            //   child: const Text('新規登録はこちら'),
            // ),
          ],
        ),
      ),
    );
  }

  String _errorMessage(Object error) => error is BloomApiException
      ? error.errorDetail
      : 'ログインに失敗しました。通信状態を確認してください。';
}
