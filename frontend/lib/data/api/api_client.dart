import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.read(dioProvider);
  return ApiClient(dio);
});

class ApiClient {
  ApiClient(this._dio);
  final Dio _dio;

  // Auth
  Future<Response> register(String email, String password) => _dio.post('/api/v1/auth/register', data: {
        'email': email,
        'password': password,
      });
  Future<Response> login(String email, String password) => _dio.post('/api/v1/auth/login', data: {
        'email': email,
        'password': password,
      });
  Future<Response> refresh(String refreshToken) => _dio.post('/api/v1/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

  // Groups
  Future<Response> listGroups({int? limit}) => _dio.get('/api/v1/groups', queryParameters: {
        if (limit != null) 'limit': limit,
      });
  Future<Response> createGroup(String name, String type, int maxMembers, {List<int>? memberIds}) => _dio.post('/api/v1/groups', data: {
        'name': name,
        'type': type,
        'max_members': maxMembers,
        if (memberIds != null && memberIds.isNotEmpty) 'member_ids': memberIds,
      });
  Future<Response> joinGroup(int id) => _dio.post('/api/v1/groups/$id/join');
  Future<Response> leaveGroup(int id) => _dio.post('/api/v1/groups/$id/leave');
  Future<Response> transferOwner(int id, int newOwnerId) => _dio.post('/api/v1/groups/$id/transfer-owner', data: {
        'new_owner_id': newOwnerId,
      });
  Future<Response> deleteGroup(int id) => _dio.delete('/api/v1/groups/$id');
  Future<Response> banishUser(int id, int userId, String reason) => _dio.post('/api/v1/groups/$id/banish', data: {
        'user_id': userId,
        'reason': reason,
      });

  // Join requests
  Future<Response> listJoinRequests(int id) => _dio.get('/api/v1/groups/$id/join-requests');
  Future<Response> approveJoin(int id, int reqId) => _dio.post('/api/v1/groups/$id/join-requests/$reqId/approve');
  Future<Response> declineJoin(int id, int reqId) => _dio.post('/api/v1/groups/$id/join-requests/$reqId/decline');

  // Messages
  Future<Response> sendMessage(int id, String text) => _dio.post('/api/v1/groups/$id/messages', data: {
        'text': text,
      });
  Future<Response> listMessages(int id, {int? limit, String? before}) => _dio.get(
        '/api/v1/groups/$id/messages',
        queryParameters: {
          if (limit != null) 'limit': limit,
          if (before != null) 'before': before,
        },
      );

  // Users
  Future<Response> listUsers({String? q, int? limit}) => _dio.get('/api/v1/users', queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (limit != null) 'limit': limit,
      });
}
