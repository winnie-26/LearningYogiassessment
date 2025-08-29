import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/messages_repository.dart';
import '../../data/repositories/groups_repository.dart';
import '../../core/providers.dart';

class MessagesNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref ref;
  final int groupId;
  bool _hasMore = true;
  bool _isLoading = false;
  
  MessagesNotifier(this.ref, this.groupId) : super(const AsyncValue.loading()) {
    loadMessages();
  }
  
  Future<void> loadMessages({bool loadMore = false}) async {
    if (_isLoading || (!loadMore && state.hasValue && state.value!.isNotEmpty)) return;
    
    _isLoading = true;
    
    try {
      final repo = ref.read(messagesRepositoryProvider);
      final currentMessages = state.value ?? [];
      
      final oldestMessage = loadMore && currentMessages.isNotEmpty 
          ? currentMessages.first['created_at'] as String 
          : null;
      
      final newMessages = await repo.list(
        groupId, 
        limit: 20, 
        before: oldestMessage,
      );
      
      _hasMore = newMessages.length == 20; // If we got a full page, there might be more
      
      state = AsyncValue.data([
        ...(loadMore ? currentMessages : []),
        ...newMessages.whereType<Map>().map((e) => e.cast<String, dynamic>()),
      ]);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    } finally {
      _isLoading = false;
    }
  }
  
  Future<void> refresh() async {
    _hasMore = true;
    state = const AsyncValue.loading();
    await loadMessages();
  }
  
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
}

final messagesProvider = StateNotifierProvider.family<MessagesNotifier, AsyncValue<List<Map<String, dynamic>>>, int>((ref, groupId) {
  return MessagesNotifier(ref, groupId);
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  bool _sending = false;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _text.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleGroupPrivacy() async {
    if (!mounted) return;
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final rawId = args['id'] ?? 0;
    final groupId = rawId is num ? rawId.toInt() : int.tryParse(rawId.toString()) ?? 0;
    final currentIsPrivate = args['isPrivate'] == true;
    final newType = currentIsPrivate ? 'public' : 'private';

    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(groupsRepositoryProvider);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Switching group to ${newType.toUpperCase()}...')),
    );
    try {
      await repo.update(groupId, type: newType);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Group is now ${newType.toUpperCase()}')),
      );
      // Update args and trigger rebuild so UI (lock icon) reflects new state
      if (mounted) {
        setState(() {
          args['isPrivate'] = (newType == 'private');
        });
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to toggle privacy: $e')),
      );
    }
  }

  Future<void> _showJoinRequests() async {
    if (!mounted) return;
    // TODO: Implement join requests dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Showing join requests...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final rawId = args['id'] ?? 0;
    final groupId = rawId is num ? rawId.toInt() : int.tryParse(rawId.toString()) ?? 0;
    final name = args['name']?.toString() ?? 'Chat';
    final isPrivate = args['isPrivate'] == true;
    final ownerId = args['ownerId']?.toString();
    
    final currentUserIdAsync = ref.watch(currentUserIdProvider);
    return currentUserIdAsync.when(
      data: (currentUserId) {
        final normalizedOwnerId = ownerId?.toString().trim();
        final normalizedCurrentUserId = currentUserId?.toString().trim();
        debugPrint('Owner ID: $normalizedOwnerId, Current User ID: $normalizedCurrentUserId');
        final isOwner = normalizedOwnerId != null && normalizedCurrentUserId != null && normalizedOwnerId == normalizedCurrentUserId;
        debugPrint('Is owner: $isOwner');
        final messagesAsync = ref.watch(messagesProvider(groupId));
        final messagesNotifier = ref.read(messagesProvider(groupId).notifier);
    
    // Handle scroll to load more
    void _onScroll() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 100) {
        if (messagesNotifier.hasMore && !messagesNotifier.isLoading) {
          messagesNotifier.loadMessages(loadMore: true);
        }
      }
    }
    
    // Add scroll listener
    _scrollController.addListener(_onScroll);

        return Scaffold(
          appBar: AppBar(
            title: Text(name),
            actions: [
              if (isOwner) ...[
                IconButton(
                  icon: Icon(isPrivate ? Icons.lock : Icons.lock_open),
                  onPressed: _toggleGroupPrivacy,
                  tooltip: isPrivate ? 'Make Public' : 'Make Private',
                ),
                IconButton(
                  icon: const Icon(Icons.group_add),
                  onPressed: _showJoinRequests,
                  tooltip: 'Manage Join Requests',
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: messagesNotifier.refresh,
                  child: messagesAsync.when(
                    data: (messages) {
                    if (messages.isEmpty) {
                      return const Center(child: Text('No messages yet'));
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8.0),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final senderName = message['sender']?['name']?.toString() ?? 'Unknown';
                        final messageText = message['text']?.toString() ?? '';
                        final messageTime = message['created_at'] != null 
                            ? DateTime.parse(message['created_at']).toString().substring(0, 19)
                            : '';
                            
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                          child: ListTile(
                            title: Text(messageText),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'By: $senderName',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (messageTime.isNotEmpty)
                                  Text(
                                    messageTime,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                            trailing: isOwner
                                ? IconButton(
                                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                    onPressed: () async {
                                      try {
                                        final repo = ref.read(messagesRepositoryProvider);
                                        await repo.deleteMessage(groupId, message['id']);
                                        messagesNotifier.refresh();
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Failed to delete message: $e')),
                                          );
                                        }
                                      }
                                    },
                                    tooltip: 'Delete message',
                                  )
                                : null,
                          ),
                        );
                      },
                    );
                  },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Failed to load messages\n$error',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: messagesNotifier.refresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onSubmitted: (_) => _sendMessage(groupId),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      onPressed: _sending ? null : () => _sendMessage(groupId),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) {
        // In case of error determining current user, default to non-owner UI
        final messagesAsync = ref.watch(messagesProvider(groupId));
        final messagesNotifier = ref.read(messagesProvider(groupId).notifier);

        // Handle scroll to load more
        void _onScroll() {
          if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 100) {
            if (messagesNotifier.hasMore && !messagesNotifier.isLoading) {
              messagesNotifier.loadMessages(loadMore: true);
            }
          }
        }
        _scrollController.addListener(_onScroll);

        return Scaffold(
          appBar: AppBar(title: Text(name)),
          body: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: messagesNotifier.refresh,
                  child: messagesAsync.when(
                    data: (messages) {
                      if (messages.isEmpty) return const Center(child: Text('No messages yet'));
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8.0),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final senderName = message['sender']?['name']?.toString() ?? 'Unknown';
                          final messageText = message['text']?.toString() ?? '';
                          final messageTime = message['created_at'] != null ? DateTime.parse(message['created_at']).toString().substring(0, 19) : '';
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                            child: ListTile(
                              title: Text(messageText),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('By: $senderName', style: Theme.of(context).textTheme.bodySmall),
                                  if (messageTime.isNotEmpty)
                                    Text(
                                      messageTime,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey[600],
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Failed to load messages\n$error', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          const SizedBox(height: 8),
                          TextButton(onPressed: messagesNotifier.refresh, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendMessage(int groupId) async {
    if (_text.text.trim().isEmpty) return;
    
    setState(() => _sending = true);
    
    try {
      final repo = ref.read(messagesRepositoryProvider);
      await repo.send(groupId, _text.text);
      _text.clear();
      // Refresh the messages to show the new one
      ref.read(messagesProvider(groupId).notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }
}
