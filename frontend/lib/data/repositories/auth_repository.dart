import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_client.dart';
import '../../core/providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(secureStorageProvider);
  return AuthRepository(api, storage);
});

class AuthRepository {
  AuthRepository(this._api, this._storage);
  final ApiClient _api;
  final FlutterSecureStorage _storage;

  Future<void> register(String email, String password) async {
    await _api.register(email, password);
  }

  Future<void> login(String email, String password) async {
    final res = await _api.login(email, password);
    final body = res.data;
    Map<String, dynamic> data;
    if (body is Map<String, dynamic>) {
      data = body;
    } else {
      data = <String, dynamic>{};
    }
    // Support multiple token key shapes
    String? access = (data['access'] ?? data['access_token']) as String?;
    String? refresh = (data['refresh'] ?? data['refresh_token']) as String?;
    // Sometimes wrapped under `data`
    if ((access == null || refresh == null) && data['data'] is Map<String, dynamic>) {
      final inner = data['data'] as Map<String, dynamic>;
      access ??= (inner['access'] ?? inner['access_token']) as String?;
      refresh ??= (inner['refresh'] ?? inner['refresh_token']) as String?;
    }
    if (access != null) {
      await _storage.write(key: 'accessToken', value: access);
    }
    if (refresh != null) {
      await _storage.write(key: 'refreshToken', value: refresh);
    }
    // Debug logging (non-sensitive length only)
    // ignore: avoid_print
    print('[AuthRepository] login stored tokens: access=${access != null ? access.length : 0} chars, refresh=${refresh != null ? refresh.length : 0} chars');
  }

  Future<void> logout() async {
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'refreshToken');
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
}
