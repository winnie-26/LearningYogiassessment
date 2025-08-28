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
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
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
  }));
  return dio;
});
