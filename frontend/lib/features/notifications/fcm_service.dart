import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmService {
  static Future<void> init() async {
    await Firebase.initializeApp();
    final messaging = FirebaseMessaging.instance;

    if (Platform.isIOS) {
      await messaging.requestPermission();
    }

    final token = await messaging.getToken();
    // TODO: send token to backend on login/refresh
    // print('FCM token: $token');

    FirebaseMessaging.onMessage.listen((message) {
      // TODO: show local notification or update chat UI
    });
  }
}
