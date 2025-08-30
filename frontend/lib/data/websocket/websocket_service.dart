import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Helper class for completing futures with timeout
class _CompletedCompleter<T> {
  final Completer<T> _completer = Completer<T>();
  bool _isCompleted = false;
  
  bool get isCompleted => _isCompleted;
  
  Future<T> get future => _completer.future;
  
  void complete(T value) {
    if (!_isCompleted) {
      _isCompleted = true;
      _completer.complete(value);
    }
  }
  
  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!_isCompleted) {
      _isCompleted = true;
      _completer.completeError(error, stackTrace);
    }
  }
}

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messageController;
  String? _currentGroupId;
  String? _currentToken;
  Timer? _heartbeatTimer;
  bool _isConnected = false;
  bool _reconnecting = false;

  // Stream for incoming messages and connection status
  Stream<Map<String, dynamic>> get messageStream => 
      _messageController?.stream ?? const Stream.empty();

  bool get isConnected => _isConnected;
  
  // Notify listeners about connection status changes
  void _notifyConnectionStatus(String status) {
    _messageController?.add({
      'type': 'connection_status',
      'status': status,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> connect(String groupId, String token) async {
    if (_currentGroupId == groupId && _isConnected) {
      print('WebSocket: Already connected to group $groupId');
      return;
    }
    
    print('WebSocket: Connecting to group $groupId...');
    await disconnect();
    
    try {
      _currentGroupId = groupId;
      _currentToken = token; // Store the token for reconnection
      _messageController = StreamController<Map<String, dynamic>>.broadcast();
      
      // WebSocket URL (without token in URL)
      final wsUrl = 'wss://learningyogiassessment-3.onrender.com/ws';
      print('WebSocket: Connecting to $wsUrl');
      
      // Notify connecting state
      _notifyConnectionStatus('connecting');
      
      // Create connection with timeout
      final connection = _CompletedCompleter<WebSocketChannel>();
      final timer = Timer(const Duration(seconds: 10), () {
        if (!connection.isCompleted) {
          connection.completeError(TimeoutException('Connection timeout'));
        }
      });
      
      // Try to establish connection
      try {
        final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
        connection.complete(channel);
      } catch (e) {
        connection.completeError(e);
      }
      
      // Wait for connection to be established
      _channel = await connection.future.whenComplete(() => timer.cancel());
      
      // Set connection status
      _isConnected = true;
      
      // Handle connection errors
      _channel!.sink.done.then((_) {
        print('WebSocket: Connection closed');
        _isConnected = false;
        _notifyConnectionStatus('disconnected');
        _reconnect();
      }).catchError((error) {
        print('WebSocket: Connection error: $error');
        _isConnected = false;
        _notifyConnectionStatus('error');
        _reconnect();
      });
      
      // Send initial authentication message
      final authMessage = {
        'type': 'auth',
        'token': token,
        'groupId': groupId,
      };
      
      print('Sending auth message: $authMessage');
      _channel!.sink.add(jsonEncode(authMessage));
      
      print('WebSocket: Connection established and authentication sent');

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

      // Send authentication message first
      final authMsg = {
        'type': 'auth',
        'token': token,
        'groupId': groupId,
      };
      print('Sending auth message: $authMsg');
      _channel!.sink.add(jsonEncode(authMsg));

      // Wait for auth to be processed
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Send join group message
      final joinMsg = {
        'type': 'join_group',
        'groupId': groupId,
      };
      print('WebSocket: Sending join group message: $joinMsg');
      _channel!.sink.add(jsonEncode(joinMsg));

      // Wait for join to be processed
      await Future.delayed(const Duration(milliseconds: 300));
      
      _isConnected = true;
      _notifyConnectionStatus('connected');
      _startHeartbeat();
      print('WebSocket: Connection established and authenticated');
      
    } catch (e) {
      print('Failed to connect WebSocket: $e');
      _isConnected = false;
      _notifyConnectionStatus('disconnected');
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

  Future<void> _reconnect() async {
    if (_currentGroupId == null || _currentToken == null) {
      print('WebSocket: Cannot reconnect - missing group ID or token');
      return;
    }
    
    // Don't try to reconnect if we're already connected or already trying to reconnect
    if (_isConnected || _reconnecting) {
      print('WebSocket: Already connected or reconnecting');
      return;
    }
    
    _reconnecting = true;
    _isConnected = false;
    
    print('WebSocket: Starting reconnection process...');
    
    // Clean up existing connection
    await disconnect();
    
    // Try to reconnect with exponential backoff
    int attempt = 0;
    const maxAttempts = 5;
    
    while (attempt < maxAttempts && !_isConnected) {
      try {
        final delay = Duration(seconds: (1 << attempt) * 2); // Exponential backoff: 2s, 4s, 8s, 16s, 32s
        print('WebSocket: Waiting ${delay.inSeconds}s before reconnection attempt ${attempt + 1}...');
        await Future.delayed(delay);
        
        print('WebSocket: Reconnection attempt ${attempt + 1} of $maxAttempts...');
        await connect(_currentGroupId!, _currentToken!);
        
        // Give it a moment to establish connection
        await Future.delayed(const Duration(seconds: 1));
        
        if (_isConnected) {
          print('WebSocket: Successfully reconnected');
          break;
        }
      } catch (e) {
        print('WebSocket: Reconnection attempt ${attempt + 1} failed: $e');
        attempt++;
      }
    }
    
    if (!_isConnected) {
      print('WebSocket: Failed to reconnect after $maxAttempts attempts');
      // Notify listeners that we're disconnected
      _messageController?.add({
        'type': 'connection_status',
        'status': 'disconnected',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      // Notify listeners that we're reconnected
      _messageController?.add({
        'type': 'connection_status',
        'status': 'reconnected',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
    
    _reconnecting = false;
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
