import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';

class TestNotificationScreen extends ConsumerWidget {
  const TestNotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Notifications'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Your FCM Token:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            FutureBuilder<String?>(
              future: FirebaseMessaging.instance.getToken(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final token = snapshot.data;
                return Column(
                  children: [
                    SelectableText(
                      token ?? 'No token available',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        if (token != null) {
                          Clipboard.setData(ClipboardData(text: token));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Token copied to clipboard'),
                            ),
                          );
                        }
                      },
                      child: const Text('Copy Token'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                await FirebaseMessaging.instance.subscribeToTopic('test');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Subscribed to test topic'),
                    ),
                  );
                }
              },
              child: const Text('Subscribe to Test Topic'),
            ),
          ],
        ),
      ),
    );
  }
}