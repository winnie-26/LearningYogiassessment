import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

final groupInvitesRepositoryProvider = Provider<GroupInvitesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GroupInvitesRepository(apiClient);
});

class GroupInvitesRepository {
  final ApiClient _apiClient;

  GroupInvitesRepository(this._apiClient);

  Future<Map<String, dynamic>> canJoinGroup(int groupId) async {
    try {
      final response = await _apiClient.canJoinGroup(groupId);
      return response.data;
    } catch (e) {
      // Handle error appropriately
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listGroupInvites(int groupId, {String? status}) async {
    try {
      final response = await _apiClient.listGroupInvites(groupId, status: status);
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      // Handle error appropriately
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createInvite(int groupId, int userId) async {
    try {
      final response = await _apiClient.createGroupInvite(groupId, userId);
      return response.data;
    } catch (e) {
      // Handle error appropriately
      rethrow;
    }
  }

  Future<Map<String, dynamic>> respondToInvite({
    required int groupId,
    required int inviteId,
    required bool accept,
  }) async {
    try {
      final response = await _apiClient.respondToInvite(
        groupId,
        inviteId,
        accept ? 'accept' : 'decline',
      );
      return response.data;
    } catch (e) {
      // Handle error appropriately
      rethrow;
    }
  }

  Future<void> revokeInvite(int groupId, int inviteId) async {
    try {
      await _apiClient.revokeInvite(groupId, inviteId);
    } catch (e) {
      // Handle error appropriately
      rethrow;
    }
  }
}
