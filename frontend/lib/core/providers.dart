import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);
  final dio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));

  // Shared refresh future to dedupe concurrent 401s
  Future<void>? refreshing;

  Future<void> performRefresh() async {
    final refreshToken = await storage.read(key: 'refreshToken');
    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('No refresh token');
    }
    // ignore: avoid_print
    print('[Dio] Performing token refresh');
    try {
      final res = await dio.post('/api/v1/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      final body = res.data;
      Map<String, dynamic> data = {};
      if (body is Map<String, dynamic>) data = body;
      String? access = (data['access'] ?? data['access_token']) as String?;
      String? newRefresh = (data['refresh'] ?? data['refresh_token']) as String?;
      if (access == null && data['data'] is Map<String, dynamic>) {
        final inner = data['data'] as Map<String, dynamic>;
        access = (inner['access'] ?? inner['access_token']) as String?;
        newRefresh ??= (inner['refresh'] ?? inner['refresh_token']) as String?;
      }
      if (access != null) await storage.write(key: 'accessToken', value: access);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await storage.write(key: 'refreshToken', value: newRefresh);
      }
      // ignore: avoid_print
      print('[Dio] Token refresh success (access len=${access?.length ?? 0})');
    } catch (e) {
      // ignore: avoid_print
      print('[Dio] Token refresh failed: $e');
      rethrow;
    }
  }

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await storage.read(key: 'accessToken');
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
        // Debug: log token length only
        // ignore: avoid_print
        print('[Dio] Attaching Authorization header (len=${token.length}) to ${options.method} ${options.path}');
      } else {
        // ignore: avoid_print
        print('[Dio] No token found for ${options.method} ${options.path}');
      }
      return handler.next(options);
    },
    onError: (error, handler) async {
      final response = error.response;
      final status = response?.statusCode;
      final path = error.requestOptions.path;
      final isAuthPath = path.contains('/api/v1/auth/');

      if (status == 401 && !isAuthPath) {
        // Prevent infinite loops: only attempt once per request
        if (error.requestOptions.extra['__retied_after_refresh__'] == true) {
          return handler.next(error);
        }

        // Dedupe concurrent refresh operations
        refreshing ??= performRefresh();
        try {
          await refreshing;
        } catch (_) {
          // Refresh failed: clear tokens so UI can redirect to login
          await storage.delete(key: 'accessToken');
          await storage.delete(key: 'refreshToken');
          return handler.next(error);
        } finally {
          refreshing = null;
        }

        // Retry the original request with updated access token
        final newToken = await storage.read(key: 'accessToken');
        final opts = error.requestOptions;
        final Options newOptions = Options(
          method: opts.method,
          headers: {
            ...opts.headers,
            if (newToken != null && newToken.isNotEmpty) 'Authorization': 'Bearer $newToken',
          },
          responseType: opts.responseType,
          contentType: opts.contentType,
          sendTimeout: opts.sendTimeout,
          receiveTimeout: opts.receiveTimeout,
          followRedirects: opts.followRedirects,
          validateStatus: opts.validateStatus,
          receiveDataWhenStatusError: opts.receiveDataWhenStatusError,
          extra: {
            ...opts.extra,
            '__retied_after_refresh__': true,
          },
        );
        try {
          final RequestOptions requestOptions = opts.copyWith(headers: newOptions.headers, extra: newOptions.extra);
          final res = await dio.fetch(requestOptions);
          return handler.resolve(res);
        } catch (e) {
          return handler.next(error);
        }
      }
      return handler.next(error);
    },
  ));

  return dio;
});

/// Provides the current user's ID.
/// Priority:
/// 1) Read 'current_user_id' from secure storage
/// 2) Fallback: decode JWT 'accessToken' payload ('sub' | 'user_id' | 'uid') and persist it
final currentUserIdProvider = FutureProvider<String?>((ref) async {
  final storage = ref.read(secureStorageProvider);
  final existing = await storage.read(key: 'current_user_id');
  if (existing != null && existing.isNotEmpty) return existing;

  final access = await storage.read(key: 'accessToken');
  if (access == null || access.isEmpty) return null;
  try {
    final parts = access.split('.');
    if (parts.length >= 2) {
      final payloadStr = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final payload = json.decode(payloadStr);
      if (payload is Map<String, dynamic>) {
        final userId = (payload['sub'] ?? payload['user_id'] ?? payload['uid'])?.toString();
        if (userId != null && userId.isNotEmpty) {
          await storage.write(key: 'current_user_id', value: userId);
          return userId;
        }
      }
    }
  } catch (_) {
    // ignore decode errors
  }
  return null;
});
