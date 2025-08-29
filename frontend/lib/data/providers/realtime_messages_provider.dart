import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/messages_repository.dart';

// Provider for real-time messages stream
final realtimeMessagesProvider = StreamProvider.family<Map<String, dynamic>, int>((ref, groupId) {
  final messagesRepo = ref.read(messagesRepositoryProvider);
  
  // Connect to WebSocket when provider is created
  messagesRepo.connectToGroup(groupId);
  
  // Clean up WebSocket when provider is disposed
  ref.onDispose(() {
    messagesRepo.disconnect();
  });
  
  return messagesRepo.messageStream;
});

// Combined provider that merges API messages with real-time messages
class CombinedMessagesNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  CombinedMessagesNotifier(this._messagesRepo, this.groupId) : super(const AsyncValue.loading()) {
    _init();
  }

  final MessagesRepository _messagesRepo;
  final int groupId;
  StreamSubscription? _realtimeSubscription;
  List<Map<String, dynamic>> _messages = [];
  bool _hasMore = true;
  bool _isLoading = false;
  int _unreadCount = 0;
  Function()? _onNewMessage;

  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;

  void setNewMessageCallback(Function() callback) {
    _onNewMessage = callback;
  }

  void markAllAsRead() {
    _unreadCount = 0;
  }

  Future<void> _init() async {
    try {
      // Load initial messages from API
      await loadMessages();
      
      // Connect to real-time stream
      await _messagesRepo.connectToGroup(groupId);
      _realtimeSubscription = _messagesRepo.messageStream.listen((newMessage) {
        _addRealtimeMessage(newMessage);
      });
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  void _addRealtimeMessage(Map<String, dynamic> message) {
    // Add new message to the end of the list (chronological order)
    _messages = [..._messages, message];
    _unreadCount++;
    state = AsyncValue.data(_messages);
    
    // Notify callback if set
    _onNewMessage?.call();
  }

  Future<void> loadMessages({bool loadMore = false}) async {
    if (_isLoading || (!loadMore && state.hasValue && state.value!.isNotEmpty)) return;
    
    _isLoading = true;
    
    try {
      final currentMessages = state.value ?? [];
      
      final oldestMessage = loadMore && currentMessages.isNotEmpty 
          ? currentMessages.first['created_at'] as String 
          : null;
      
      final newMessages = await _messagesRepo.list(
        groupId, 
        limit: 20, 
        before: oldestMessage,
      );
      
      _hasMore = newMessages.length == 20;
      
      final updatedMessages = <Map<String, dynamic>>[
        ...(loadMore ? currentMessages : []),
        ...newMessages.cast<Map<String, dynamic>>(),
      ];
      
      _messages = updatedMessages;
      state = AsyncValue.data(_messages);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await loadMessages();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _messagesRepo.disconnect();
    super.dispose();
  }
}

final combinedMessagesProvider = StateNotifierProvider.family<CombinedMessagesNotifier, AsyncValue<List<Map<String, dynamic>>>, int>((ref, groupId) {
  final messagesRepo = ref.read(messagesRepositoryProvider);
  return CombinedMessagesNotifier(messagesRepo, groupId);
});
