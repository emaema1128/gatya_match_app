import 'package:flutter/material.dart';

class HomeTabScreen extends StatelessWidget {
  const HomeTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home (placeholder)')),
      body: const Center(child: Text('Home')),
    );
  }
}
