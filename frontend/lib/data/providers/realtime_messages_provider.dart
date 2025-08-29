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
    // Add new message to the beginning of the list (most recent first)
    _messages = [message, ..._messages];
    state = AsyncValue.data(_messages);
  }

  Future<void> loadMessages({bool loadMore = false}) async {
    if (state.isLoading && !loadMore) return;
    
    try {
      final newMessages = await _messagesRepo.list(groupId, limit: 20);
      _messages = newMessages.cast<Map<String, dynamic>>();
      state = AsyncValue.data(_messages);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
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
