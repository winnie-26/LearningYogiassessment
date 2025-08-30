import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app.dart';
import 'package:frontend/services/notification_service.dart';

// Global navigator key for notifications
final GlobalKey<NavigatorState> navigatorKey = NotificationService.navigatorKey;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize notifications (handled by the NotificationService constructor)
  
  runApp(
    ProviderScope(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: const App(),
      ),
    ),
  );
}
