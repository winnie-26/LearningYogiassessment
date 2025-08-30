import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Global navigator key for accessing context in static methods
final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

// Provider for NotificationService
final notificationServiceProvider = StateNotifierProvider<NotificationService, bool>((ref) {
  return NotificationService();
});

class NotificationService extends StateNotifier<bool> {
  NotificationService() : super(false) {
    _init();
  }
  
  // Make navigator key accessible
  static final GlobalKey<NavigatorState> navigatorKey = _navigatorKey;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Initialize notifications
  Future<void> _init() async {
    try {
      // Request notification permissions
      await _requestPermissions();
      
      // Initialize local notifications
      await _initLocalNotifications();
      
      // Get initial message if app was opened from terminated state
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessage(initialMessage);
      }
      
      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Listen for background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        _saveDeviceTokenToServer(newToken);
      });
      
      // Mark as initialized
      state = true;
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }
  
  // Save device token to server and local storage
  Future<void> _saveDeviceTokenToServer(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // First, save the token locally
      await prefs.setString('fcm_token', token);
      
      // Get the container to access providers
      final container = ProviderScope.containerOf(_navigatorKey.currentContext!);
      final userService = container.read(userServiceProvider);
      
      // Get user ID
      final userId = await userService.getCurrentUserId();
      
      if (userId != null && userId.isNotEmpty) {
        // Update the token on the server
        final success = await userService.updateFcmToken(userId, token);
        if (success) {
          print('Successfully updated FCM token on server');
        } else {
          print('Failed to update FCM token on server');
        }
      } else {
        print('User ID not found, will update FCM token after login');
      }
    } catch (e) {
      print('Error saving token to server: $e');
    }
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    // Request permissions through Firebase Messaging
    await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  // Initialize local notifications
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    _showLocalNotification(message);
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final androidDetails = AndroidNotificationDetails(
      'channel_id',
      'Channel Name',
      channelDescription: 'Channel Description',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const iOSDetails = DarwinNotificationDetails();
    
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );
    
    await _localNotifications.show(
      message.notification?.hashCode ?? 0,
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  // Handle incoming messages
  void _handleMessage(RemoteMessage message) {
    // Handle the message as needed
    _showLocalNotification(message);
  }

  // Background message handler
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    // Handle background message
    // We can't call instance methods from a static method, so we'll just save the message
    // and handle it when the app is opened
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_notification', message.data.toString());
  }
}

// This function must be at the top level for background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService._firebaseMessagingBackgroundHandler(message);
}
