import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  final api = ref.read(apiClientProvider);
  return UsersRepository(api);
});

class UsersRepository {
  UsersRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> list({String? q, int? limit}) async {
    final res = await _api.listUsers(q: q, limit: limit);
    final data = res.data;
    if (data is List) {
      return data.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return <Map<String, dynamic>>[];
  }
}
