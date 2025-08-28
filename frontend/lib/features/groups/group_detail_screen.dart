import 'package:flutter/material.dart';

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final groupId = args?['id'] ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text('Group #$groupId')),
      body: const Center(child: Text('Group details here')),
    );
  }
}
