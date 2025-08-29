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
    if (_currentGroupId == groupId && _isConnected) {
      print('WebSocket: Already connected to group $groupId');
      return;
    }
    
    print('WebSocket: Connecting to group $groupId...');
    await disconnect();
    
    try {
      _currentGroupId = groupId;
      _messageController = StreamController<Map<String, dynamic>>.broadcast();
      
      // WebSocket URL for Render deployment (wss for secure WebSocket)
      final wsUrl = 'wss://learningyogiassessment-2.onrender.com/ws';
      print('WebSocket: Connecting to $wsUrl');
      
      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
      );

      // Listen for incoming messages
      _channel!.stream.listen(
        (data) {
          try {
            print('WebSocket: Received data: $data');
            final message = jsonDecode(data) as Map<String, dynamic>;
            print('WebSocket: Parsed message: $message');
            
            // Handle different message types
            switch (message['type']) {
              case 'new_message':
                print('WebSocket: Forwarding new message to controller');
                _messageController?.add(message);
                break;
              case 'pong':
                print('WebSocket: Received pong');
                break;
              case 'error':
                print('WebSocket: Error from server: ${message['message']}');
                break;
              default:
                print('WebSocket: Ignoring message type: ${message['type']}');
            }
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
      print('WebSocket: Sending auth message: $authMessage');
      _channel!.sink.add(jsonEncode(authMessage));

      // Send join group message after a short delay to ensure auth is processed
      await Future.delayed(const Duration(milliseconds: 300));
      final joinMessage = {
        'type': 'join_group',
        'groupId': groupId,
      };
      print('WebSocket: Sending join group message: $joinMessage');
      _channel!.sink.add(jsonEncode(joinMessage));

      _isConnected = true;
      _startHeartbeat();
      print('WebSocket: Connection established and authenticated');
      
    } catch (e) {
      print('Failed to connect WebSocket: $e');
      _isConnected = false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isConnected && _channel != null) {
        try {
          final ping = {'type': 'ping'};
          print('WebSocket: Sending heartbeat ping');
          _channel!.sink.add(jsonEncode(ping));
        } catch (e) {
          print('WebSocket: Error sending heartbeat: $e');
          _isConnected = false;
          _reconnect();
        }
      }
    });
  }

  void _reconnect() {
    if (_currentGroupId != null) {
      Timer(const Duration(seconds: 3), () {
        print('Attempting to reconnect WebSocket...');
        // Reconnect logic here
      });
    }
  }

  void sendMessage(String text, String senderId) {
    if (!_isConnected || _channel == null) {
      print('WebSocket: Cannot send message - not connected');
      return;
    }
    
    final messageData = {
      'type': 'message',
      'text': text,
      'sender_id': senderId,
      'group_id': _currentGroupId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    print('Sending WebSocket message: $messageData');
    try {
      _channel!.sink.add(jsonEncode(messageData));
    } catch (e) {
      print('Error sending WebSocket message: $e');
      _isConnected = false;
      _reconnect();
    }
  }

  Future<void> disconnect() async {
    print('WebSocket: Disconnecting...');
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (e) {
        print('Error closing WebSocket: $e');
      }
      _channel = null;
    }
    
    _isConnected = false;
    _currentGroupId = null;
    
    if (_messageController != null && !_messageController!.isClosed) {
      await _messageController!.close();
      _messageController = null;
    }
    print('WebSocket: Disconnected');
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
