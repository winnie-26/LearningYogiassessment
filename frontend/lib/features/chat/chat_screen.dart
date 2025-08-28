import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final groupId = args?['id'] ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text('Chat #$groupId')),
      body: Column(
        children: [
          const Expanded(child: Center(child: Text('Messages list'))),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(children: [
              const Expanded(child: TextField(decoration: InputDecoration(hintText: 'Type a message'))),
              IconButton(onPressed: () {}, icon: const Icon(Icons.send)),
            ]),
          )
        ],
      ),
    );
  }
}
