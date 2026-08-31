import 'package:flutter/material.dart';

class PointsTabScreen extends StatelessWidget {
  const PointsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ポイント (placeholder)')),
      body: const Center(child: Text('Points')),
    );
  }
}
