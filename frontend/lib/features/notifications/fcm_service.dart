import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/api_client.dart';

class FcmService {
  static FirebaseMessaging? _messaging;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;

      if (Platform.isIOS) {
        await _messaging!.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Listen for token refresh
      _messaging!.onTokenRefresh.listen((newToken) {
        print('[FCM] Token refreshed: ${newToken.substring(0, 20)}...');
        // Auto-register new token if user is logged in
        _registerTokenIfLoggedIn();
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('[FCM] Foreground message received: ${message.notification?.title}');
        // TODO: Show local notification or update chat UI
      });

      // Handle background message taps
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('[FCM] Message opened app: ${message.notification?.title}');
        // TODO: Navigate to appropriate screen
      });

      print('[FCM] Service initialized successfully');
    } catch (error) {
      print('[FCM] Initialization error: $error');
    }
  }

  /// Register FCM token with backend
  static Future<bool> registerToken(ProviderContainer container) async {
    try {
      if (_messaging == null) {
        print('[FCM] Messaging not initialized');
        return false;
      }

      final token = await _messaging!.getToken();
      if (token == null) {
        print('[FCM] No token available');
        return false;
      }

      print('[FCM] Registering token: ${token.substring(0, 20)}...');

      final apiClient = container.read(apiClientProvider);
      final response = await apiClient.updateFcmToken(token);

      if (response.statusCode == 200) {
        print('[FCM] Token registered successfully');
        return true;
      } else {
        print('[FCM] Token registration failed: ${response.statusCode}');
        return false;
      }
    } catch (error) {
      print('[FCM] Token registration error: $error');
      return false;
    }
  }

  /// Remove FCM token from backend (logout)
  static Future<bool> removeToken(ProviderContainer container) async {
    try {
      final apiClient = container.read(apiClientProvider);
      final response = await apiClient.removeFcmToken();

      if (response.statusCode == 200) {
        print('[FCM] Token removed successfully');
        return true;
      } else {
        print('[FCM] Token removal failed: ${response.statusCode}');
        return false;
      }
    } catch (error) {
      print('[FCM] Token removal error: $error');
      return false;
    }
  }

  /// Get current FCM token
  static Future<String?> getCurrentToken() async {
    if (_messaging == null) return null;
    return await _messaging!.getToken();
  }

  /// Auto-register token if user is logged in (called on token refresh)
  static Future<void> _registerTokenIfLoggedIn() async {
    // TODO: Check if user is logged in and auto-register
    // This would require access to auth state
    print('[FCM] Token refresh detected - manual re-registration may be needed');
  }
}
