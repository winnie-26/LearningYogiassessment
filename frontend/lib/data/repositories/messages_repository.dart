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
    return (res.data as List).cast<dynamic>();
  }
}
