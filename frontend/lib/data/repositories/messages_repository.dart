import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  final api = ref.read(apiClientProvider);
  return MessagesRepository(api);
});

class MessagesRepository {
  MessagesRepository(this._api);
  final ApiClient _api;

  Future<void> send(int groupId, String text) => _api.sendMessage(groupId, text).then((_) {});
  
  Future<List<dynamic>> list(int groupId, {int? limit, String? before}) async {
    final res = await _api.listMessages(groupId, limit: limit, before: before);
    final body = res.data;
    if (body is List) {
      return body.cast<dynamic>();
    }
    if (body is Map) {
      final candidates = ['data', 'messages', 'items', 'results'];
      for (final key in candidates) {
        final val = body[key];
        if (val is List) return val.cast<dynamic>();
        if (val is Map) {
          for (final innerKey in candidates) {
            final inner = val[innerKey];
            if (inner is List) return inner.cast<dynamic>();
          }
        }
      }
    }
    return <dynamic>[];
  }
  
  Future<void> deleteMessage(int groupId, dynamic messageId) async {
    await _api.deleteMessage(groupId, messageId);
  }
}
