import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/router/app_routes.dart';

class SettingsTabScreen extends ConsumerWidget {
  const SettingsTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('マイページ')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => const ProfileRoute().push(context),
              child: const Text('プロフィールを編集'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.read(authControllerProvider.notifier).logOut(),
              child: const Text('ログアウト'),
            ),
          ],
        ),
      ),
    );
  }
}
