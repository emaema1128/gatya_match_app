import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../chat/application/talk_list_controller.dart';

class HomeShellScreen extends StatelessWidget {
  const HomeShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) =>
            navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.favorite_outline), label: 'Like'),
          NavigationDestination(icon: _buildChatIcon(), label: 'チャット'),
          const NavigationDestination(icon: Icon(Icons.person_outline), label: 'マイページ'),
          const NavigationDestination(icon: Icon(Icons.attach_money_outlined), label: 'ポイント'),
        ],
      ),
    );
  }

  Widget _buildChatIcon() {
    return Consumer(
      builder: (context, ref, _) {
        final unread = ref.watch(totalUnreadChatCountProvider);
        return Badge(
          label: Text('$unread'),
          isLabelVisible: unread > 0,
          child: const Icon(Icons.chat_bubble_outline),
        );
      },
    );
  }
}
