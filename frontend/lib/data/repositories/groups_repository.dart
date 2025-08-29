import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  final api = ref.read(apiClientProvider);
  return GroupsRepository(api);
});

class GroupsRepository {
  GroupsRepository(this._api);
  final ApiClient _api;

  Future<List<dynamic>> list({int? limit}) async {
    final res = await _api.listGroups(limit: limit);
    final body = res.data;
    if (body is List) {
      // ignore: avoid_print
      print('[GroupsRepository] list: parsed ${body.length} (raw list)');
      return body.cast<dynamic>();
    }
    if (body is Map) {
      final map = body;
      final candidates = ['data', 'groups', 'items'];
      for (final key in candidates) {
        final val = map[key];
        if (val is List) return val.cast<dynamic>();
        // Sometimes wrapped as a nested map: { data: { items: [...] } }
        if (val is Map) {
          for (final innerKey in candidates) {
            final inner = val[innerKey];
            if (inner is List) {
              // ignore: avoid_print
              print('[GroupsRepository] list: parsed ${inner.length} from nested "$key.$innerKey"');
              return inner.cast<dynamic>();
            }
          }
        }
      }
    }
    // Fallback to empty list if shape unexpected
    // ignore: avoid_print
    print('[GroupsRepository] list: unknown response shape -> returning empty list');
    return <dynamic>[];
  }

  Future<Map<String, dynamic>> create(String name, String type, int maxMembers, {List<int>? memberIds}) async {
    final res = await _api.createGroup(name, type, maxMembers, memberIds: memberIds);
    return (res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> joinGroup(int groupId) async {
    final res = await _api.joinGroup(groupId);
    return (res.data as Map<String, dynamic>);
  }

  Future<void> join(int id) => _api.joinGroup(id).then((_) {});
  Future<void> leave(int id) => _api.leaveGroup(id).then((_) {});
  Future<void> transferOwner(int id, int newOwnerId) => _api.transferOwner(id, newOwnerId).then((_) {});
  Future<void> delete(int id) => _api.deleteGroup(id).then((_) {});
  Future<void> banish(int id, int userId, String reason) => _api.banishUser(id, userId, reason).then((_) {});

  Future<void> update(int id, {String? name, String? type, int? maxMembers}) async {
    await _api.updateGroup(id, name: name, type: type, maxMembers: maxMembers);
  }
}
