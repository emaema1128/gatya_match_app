import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';

/// 設定画面。プロフィール画面(マイページタブ)の歯車アイコンからpushされる。
/// 現状はログアウトのみ(将来ここに設定項目を増やしていく想定)。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => ref.read(authControllerProvider.notifier).logOut(),
          child: const Text('ログアウト'),
        ),
      ),
    );
  }
}
