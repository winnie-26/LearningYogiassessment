import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  final List<T> items;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json, 
    T Function(dynamic) fromJson
  ) {
    return PaginatedResponse<T>(
      items: (json['data'] as List).map(fromJson).toList(),
      total: json['pagination']['total'] as int,
      limit: json['pagination']['limit'] as int,
      offset: json['pagination']['offset'] as int,
      hasMore: json['pagination']['hasMore'] as bool,
    );
  }
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  final api = ref.read(apiClientProvider);
  return UsersRepository(api);
});

class UsersRepository {
  UsersRepository(this._api);
  final ApiClient _api;

  Future<PaginatedResponse<Map<String, dynamic>>> list({
    String? q, 
    int? limit, 
    int? offset
  }) async {
    try {
      final res = await _api.listUsers(
        q: q, 
        limit: limit,
        offset: offset,
      );
      
      return PaginatedResponse<Map<String, dynamic>>.fromJson(
        res.data as Map<String, dynamic>,
        (item) => (item as Map).cast<String, dynamic>(),
      );
    } catch (e) {
      // Return empty paginated response on error
      return PaginatedResponse<Map<String, dynamic>>(
        items: const [],
        total: 0,
        limit: limit ?? 20,
        offset: offset ?? 0,
        hasMore: false,
      );
    }
  }
}
