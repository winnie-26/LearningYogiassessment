import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messageController;
  String? _currentGroupId;
  Timer? _heartbeatTimer;
  bool _isConnected = false;

  // Stream for incoming messages
  Stream<Map<String, dynamic>> get messageStream => 
      _messageController?.stream ?? const Stream.empty();

  bool get isConnected => _isConnected;

  Future<void> connect(String groupId, String token) async {
    if (_currentGroupId == groupId && _isConnected) return;
    
    await disconnect();
    
    try {
      _currentGroupId = groupId;
      _messageController = StreamController<Map<String, dynamic>>.broadcast();
      
      // WebSocket URL for Render deployment (wss for secure WebSocket)
      final wsUrl = 'wss://learningyogiassessment-2.onrender.com/ws';
      print('Connecting to WebSocket: $wsUrl'); // Debug log
      
      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        // Add authorization header if your backend supports it
        // protocols: ['Bearer $token'],
      );

      // Listen for incoming messages
      _channel!.stream.listen(
        (data) {
          try {
            print('WebSocket received: $data'); // Debug log
            final message = jsonDecode(data);
            print('Parsed message: $message'); // Debug log
            _messageController?.add(message);
          } catch (e) {
            print('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
          _reconnect();
        },
        onDone: () {
          print('WebSocket connection closed');
          _isConnected = false;
          _reconnect();
        },
      );

      // Send authentication message
      final authMessage = {
        'type': 'auth',
        'token': token,
        'groupId': groupId,
      };
      print('Sending auth message: $authMessage'); // Debug log
      _channel!.sink.add(jsonEncode(authMessage));

      _isConnected = true;
      _startHeartbeat();
      
    } catch (e) {
      print('Failed to connect WebSocket: $e');
      _isConnected = false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        _channel!.sink.add(jsonEncode({'type': 'ping'}));
      }
    });
  }

  void _reconnect() {
    if (_currentGroupId != null) {
      Timer(Duration(seconds: 3), () {
        // You'll need to get the token again for reconnection
        // This is a simplified version - you might want to store the token
        print('Attempting to reconnect WebSocket...');
      });
    }
  }

  void sendMessage(String text, String senderId) {
    if (_isConnected && _channel != null) {
      final messageData = {
        'type': 'message',
        'text': text,
        'sender_id': senderId,
        'group_id': _currentGroupId,
        'timestamp': DateTime.now().toIso8601String(),
      };
      print('Sending WebSocket message: $messageData'); // Debug log
      _channel!.sink.add(jsonEncode(messageData));
    } else {
      print('WebSocket not connected, cannot send message'); // Debug log
    }
  }

  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _isConnected = false;
    _currentGroupId = null;
    
    await _channel?.sink.close();
    _channel = null;
    
    await _messageController?.close();
    _messageController = null;
  }
}

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  
  // Clean up when provider is disposed
  ref.onDispose(() {
    service.disconnect();
  });
  
  return service;
});
