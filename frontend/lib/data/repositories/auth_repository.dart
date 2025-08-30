import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../../core/providers.dart';
import '../../services/user_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(secureStorageProvider);
  final userService = ref.read(userServiceProvider);
  return AuthRepository(api, storage, userService);
});

class AuthRepository {
  AuthRepository(this._api, this._storage, this._userService);
  final ApiClient _api;
  final FlutterSecureStorage _storage;
  final UserService _userService;

  // Get the current user ID from secure storage
  Future<String?> get _userId async {
    return await _storage.read(key: 'userId');
  }

  Future<void> register(String email, String password) async {
    final response = await _api.register(email, password);
    // After successful registration, save user ID and update FCM token
    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      final userId = data['user_id']?.toString();
      if (userId != null) {
        await _storage.write(key: 'userId', value: userId);
        // Update FCM token for the new user
        await _updateFcmTokenForUser(userId);
      }
    }
  }

  Future<void> login(String email, String password) async {
    final res = await _api.login(email, password);
    final body = res.data;
    print('Login response: $body');
    
    Map<String, dynamic> data;
    if (body is Map<String, dynamic>) {
      data = body;
    } else {
      data = <String, dynamic>{};
    }
    
    print('Parsed login data: $data');
    // Support multiple token key shapes
    String? access = (data['access'] ?? data['access_token']) as String?;
    String? refresh = (data['refresh'] ?? data['refresh_token']) as String?;
    String? userId = data['user_id']?.toString();
    
    // Sometimes wrapped under `data`
    if ((access == null || refresh == null) && data['data'] is Map<String, dynamic>) {
      final inner = data['data'] as Map<String, dynamic>;
      access ??= (inner['access'] ?? inner['access_token']) as String?;
      refresh ??= (inner['refresh'] ?? inner['refresh_token']) as String?;
      userId ??= inner['user_id']?.toString();
    }
    
    if (access != null) {
      await _storage.write(key: 'accessToken', value: access);
    }
    if (refresh != null) {
      await _storage.write(key: 'refreshToken', value: refresh);
    }
    if (userId != null) {
      await _storage.write(key: 'userId', value: userId);
      // Update FCM token for the logged-in user
      await _updateFcmTokenForUser(userId);
    } else {
      // Try to get user ID from other possible locations in the response
      userId = data['id']?.toString();
      if (userId == null && data['user'] is Map<String, dynamic>) {
        final user = data['user'] as Map<String, dynamic>;
        userId = (user['id'] ?? user['user_id'])?.toString();
      }
      if (userId == null && data['data'] is Map<String, dynamic>) {
        final inner = data['data'] as Map<String, dynamic>;
        userId = inner['user_id']?.toString() ?? inner['id']?.toString();
        if (userId == null && inner['user'] is Map<String, dynamic>) {
          final user = inner['user'] as Map<String, dynamic>;
          userId = (user['id'] ?? user['user_id'])?.toString();
        }
      }
      
      // If we found the user ID in another location, store it
      if (userId != null) {
        await _storage.write(key: 'userId', value: userId);
        await _updateFcmTokenForUser(userId);
      }
    }
    
    // Fallback: decode JWT access token for `sub`/`user_id`/`uid`
    if (userId == null && access != null) {
      try {
        final parts = access.split('.');
        if (parts.length >= 2) {
          final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
          if (payload is Map<String, dynamic>) {
            userId = (payload['sub'] ?? payload['user_id'] ?? payload['uid'])?.toString();
          }
        }
      } catch (e) {
        // ignore decoding errors
      }
    }
    print('Extracted user ID: $userId');
    
    if (userId != null) {
      print('Storing user ID in secure storage');
      await _storage.write(key: 'current_user_id', value: userId);
      
      // Verify the ID was stored
      final storedId = await _storage.read(key: 'current_user_id');
      print('Stored user ID verification: $storedId');
    } else {
      print('No user ID found in login response');
    }
    // Debug logging (non-sensitive length only)
    // ignore: avoid_print
    print('[AuthRepository] login stored tokens: access=${access != null ? access.length : 0} chars, refresh=${refresh != null ? refresh.length : 0} chars');
  }

  Future<void> logout() async {
    // Clear FCM token on logout
    await _clearFcmToken(await _userId);
    
    // Clear all stored data
    await _storage.deleteAll();
    
    // Clear shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
  
  Future<void> _clearFcmToken(String? userId) async {
    try {
      if (userId != null) {
        await _userService.updateFcmToken(userId, '');
      }
    } catch (e) {
      print('Error clearing FCM token: $e');
    }
  }

  // Helper method to update FCM token for a user
  Future<void> _updateFcmTokenForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fcm_token');
      
      if (token != null && token.isNotEmpty) {
        await _userService.updateFcmToken(userId, token);
      }
    } catch (e) {
      print('Error updating FCM token for user: $e');
    }
  }

  Future<void> refresh() async {
    final refresh = await _storage.read(key: 'refreshToken');
    if (refresh == null) return;
    final res = await _api.refresh(refresh);
    final body = res.data;
    Map<String, dynamic> data = {};
    if (body is Map<String, dynamic>) data = body;
    String? access = (data['access'] ?? data['access_token']) as String?;
    if (access == null && data['data'] is Map<String, dynamic>) {
      final inner = data['data'] as Map<String, dynamic>;
      access = (inner['access'] ?? inner['access_token']) as String?;
    }
    if (access != null) await _storage.write(key: 'accessToken', value: access);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'accessToken');
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final userId = await _storage.read(key: 'current_user_id');
    if (userId != null) {
      return {'id': userId};
    }
    return null;
  }
}
