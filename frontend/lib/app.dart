import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/groups/groups_list_screen.dart';
import 'features/groups/group_detail_screen.dart';
import 'features/groups/create_group_screen.dart';
import 'features/join_requests/join_requests_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/storage/local_cache.dart';
import 'features/notifications/fcm_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _ready = false;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await LocalCache.init();
    } catch (e) {
      debugPrint('[Bootstrap] LocalCache.init failed: $e');
    }
    try {
      await FcmService.init();
    } catch (e) {
      debugPrint('[Bootstrap] FcmService.init failed: $e');
    }
    // Determine login state based on token
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'accessToken');
      _loggedIn = token != null && token.isNotEmpty;
      // ignore: avoid_print
      print('[App] loggedIn=$_loggedIn (tokenLen=${token?.length ?? 0})');
    } catch (e) {
      debugPrint('[Bootstrap] Reading token failed: $e');
      _loggedIn = false;
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }
    return MaterialApp(
      title: 'Group Messaging',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
      home: _loggedIn ? const GroupsListScreen() : const LoginScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/groups': (_) => const GroupsListScreen(),
        '/group': (_) => const GroupDetailScreen(),
        '/group-detail': (_) => const GroupDetailScreen(),
        '/create-group': (_) => const CreateGroupScreen(),
        '/join-requests': (_) => const JoinRequestsScreen(),
        '/chat': (_) => const ChatScreen(),
      },
    );
  }
}
