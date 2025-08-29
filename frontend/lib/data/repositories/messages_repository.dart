import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../api/api_client.dart';
import '../websocket/websocket_service.dart';
import 'auth_repository.dart';

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  final api = ref.read(apiClientProvider);
  final webSocket = ref.read(webSocketServiceProvider);
  final auth = ref.read(authRepositoryProvider);
  return MessagesRepository(api, webSocket, auth);
});

class MessagesRepository {
  MessagesRepository(this._api, this._webSocket, this._auth);
  final ApiClient _api;
  final WebSocketService _webSocket;
  final AuthRepository _auth;

  // Connect to WebSocket for real-time messages
  Future<void> connectToGroup(int groupId) async {
    final token = await _auth.getToken();
    if (token != null) {
      await _webSocket.connect(groupId.toString(), token);
    }
  }

  // Get real-time message stream
  Stream<Map<String, dynamic>> get messageStream => _webSocket.messageStream;

  // Send message via API and WebSocket
  Future<void> send(int groupId, String text) async {
    // Send via API first
    await _api.sendMessage(groupId, text);
    
    // Also send via WebSocket for real-time delivery
    final user = await _auth.getCurrentUser();
    final senderId = user?['id']?.toString() ?? '';
    _webSocket.sendMessage(text, senderId);
  }

  // Disconnect WebSocket
  Future<void> disconnect() async {
    await _webSocket.disconnect();
  }
  
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
