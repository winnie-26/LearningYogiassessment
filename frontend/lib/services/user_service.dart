import 'package:frontend/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

final userServiceProvider = Provider<UserService>((ref) {
  return UserService(ref);
});

class UserService {
  final Ref _ref;
  late final FlutterSecureStorage _storage;
  
  UserService(this._ref) {
    _storage = const FlutterSecureStorage();
  }

  Future<bool> updateFcmToken(String userId, String token) async {
    try {
      final dio = _ref.read(dioProvider);
      
      // If token is empty, we're just clearing it
      if (token.isEmpty) {
        print('Clearing FCM token for user $userId');
      } else {
        print('Updating FCM token for user $userId');
      }
      
      final response = await dio.post<Map<String, dynamic>>(
        '/users/$userId/fcm-token',
        data: {'fcmToken': token},
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      print('Error updating FCM token: ${e.message}');
      if (e.response != null) {
        print('Response data: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      print('Unexpected error updating FCM token: $e');
      return false;
    }
  }
  
  // Get current user ID
  Future<String?> getCurrentUserId() async {
    return await _storage.read(key: 'userId');
  }
}
