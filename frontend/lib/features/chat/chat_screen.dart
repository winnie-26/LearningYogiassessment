import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/data/api/api_client.dart';
import '../../data/repositories/messages_repository.dart';
import '../../data/repositories/groups_repository.dart';
import '../../data/providers/realtime_messages_provider.dart';
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
  final TextEditingController _text = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  String? _resolvedOwnerId;
  bool _isAtBottom = true;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _text.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final isAtBottom = _scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 100;
      
      if (_isAtBottom != isAtBottom) {
        setState(() {
          _isAtBottom = isAtBottom;
          _showScrollToBottom = !isAtBottom;
        });
        
        // Mark messages as read when at bottom
        if (isAtBottom) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          final rawId = args['id'] ?? 0;
          final groupId = rawId is num ? rawId.toInt() : int.tryParse(rawId.toString()) ?? 0;
          ref.read(combinedMessagesProvider(groupId).notifier).markAllAsRead();
        }
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onNewMessage() {
    // Auto-scroll to bottom if user is already at bottom
    if (_isAtBottom && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
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
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final rawId = args['id'] ?? 0;
    final groupId = rawId is num ? rawId.toInt() : int.tryParse(rawId.toString()) ?? 0;

    final api = ref.read(apiClientProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final res = await api.listJoinRequests(groupId);
      dynamic body = res.data;
      List<dynamic> requests;
      if (body is List) {
        requests = body;
      } else if (body is Map) {
        final map = body as Map<String, dynamic>;
        final candidates = ['data', 'items', 'requests'];
        List<dynamic>? found;
        for (final key in candidates) {
          final val = map[key];
          if (val is List) { found = val; break; }
          if (val is Map) {
            for (final innerKey in candidates) {
              final inner = val[innerKey];
              if (inner is List) { found = inner; break; }
            }
          }
          if (found != null) break;
        }
        requests = found ?? <dynamic>[];
      } else {
        requests = <dynamic>[];
      }

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocalState) {
              return AlertDialog(
                title: const Text('Join Requests'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: requests.isEmpty
                      ? const Text('No pending requests')
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            final req = requests[index] as Map<String, dynamic>;
                            final id = req['id'] ?? req['req_id'] ?? index;
                            final userId = req['user_id'] ?? req['userId'] ?? 'Unknown';
                            final status = (req['status'] ?? '').toString();
                            return ListTile(
                              title: Text('User #$userId'),
                              subtitle: Text(status.isEmpty ? 'pending' : status),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Approve',
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    onPressed: status == 'approved' ? null : () async {
                                      try {
                                        await api.approveJoin(groupId, (id as num).toInt());
                                        messenger.showSnackBar(const SnackBar(content: Text('Approved request')));
                                        setLocalState(() {
                                          req['status'] = 'approved';
                                        });
                                      } catch (e) {
                                        messenger.showSnackBar(SnackBar(content: Text('Failed to approve: $e')));
                                      }
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Decline',
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: status == 'declined' ? null : () async {
                                      try {
                                        await api.declineJoin(groupId, (id as num).toInt());
                                        messenger.showSnackBar(const SnackBar(content: Text('Declined request')));
                                        setLocalState(() {
                                          req['status'] = 'declined';
                                        });
                                      } catch (e) {
                                        messenger.showSnackBar(SnackBar(content: Text('Failed to decline: $e')));
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to load join requests: $e')),
      );
    }
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
        // Determine effective owner id: from args or previously resolved fallback
        String? effectiveOwnerId = (ownerId ?? _resolvedOwnerId)?.toString();

        // If ownerId missing, try to resolve it once from groups list
        if (effectiveOwnerId == null || effectiveOwnerId.isEmpty) {
          // fire-and-forget resolve; safe because setState guarded by mounted
          Future.microtask(() async {
            try {
              final repo = ref.read(groupsRepositoryProvider);
              final groups = await repo.list(limit: 100);
              final found = groups.cast<Map>().firstWhere(
                (g) => ((g['id'] ?? g['group_id'])?.toString() == groupId.toString()),
                orElse: () => const {},
              );
              final owner = (found['owner_id'] ?? found['ownerId'])?.toString();
              if (owner != null && owner.isNotEmpty && mounted) {
                setState(() {
                  _resolvedOwnerId = owner;
                });
              }
            } catch (_) {
              // ignore failures; UI will behave as non-owner until resolved
            }
          });
        }

        final normalizedOwnerId = effectiveOwnerId?.trim();
        final normalizedCurrentUserId = currentUserId?.toString().trim();
        debugPrint('Owner ID: $normalizedOwnerId, Current User ID: $normalizedCurrentUserId');
        final isOwner = normalizedOwnerId != null && normalizedCurrentUserId != null && normalizedOwnerId == normalizedCurrentUserId;
        debugPrint('Is owner: $isOwner');
        final messagesAsync = ref.watch(combinedMessagesProvider(groupId));
        final messagesNotifier = ref.read(combinedMessagesProvider(groupId).notifier);
        
        // Set up new message callback for auto-scroll
        messagesNotifier.setNewMessageCallback(_onNewMessage);

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Text(name),
            actions: [
              if (isOwner) ...[
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showJoinRequests,
                  tooltip: 'Manage Join Requests',
                ),
                IconButton(
                  icon: Icon(isPrivate ? Icons.lock : Icons.lock_open),
                  onPressed: _toggleGroupPrivacy,
                  tooltip: isPrivate ? 'Make Public' : 'Make Private',
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
                    return Stack(
                      children: [
                        ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8.0),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                        final message = messages[index];
                        final senderMap = message['sender'];
                        final senderName = senderMap?['name']?.toString() ?? 'Unknown';
                        final currentSenderIdStr = (() {
                          if (senderMap is Map) {
                            final raw = senderMap['id'] ?? senderMap['user_id'] ?? senderMap['uid'];
                            if (raw != null) return raw.toString();
                          }
                          return null;
                        })();
                        final prevSenderIdStr = (() {
                          if (index > 0) {
                            final prev = messages[index - 1];
                            final prevSender = prev['sender'];
                            if (prevSender is Map) {
                              final raw = prevSender['id'] ?? prevSender['user_id'] ?? prevSender['uid'];
                              if (raw != null) return raw.toString();
                            }
                          }
                          return null;
                        })();
                        final showSenderName = index == 0 || (currentSenderIdStr ?? '') != (prevSenderIdStr ?? '');
                        final messageText = message['text']?.toString() ?? '';
                        final isCurrentUser = currentSenderIdStr != null && currentSenderIdStr.trim() == normalizedCurrentUserId;
                        
                        // Generate different shades for different users
                        final senderHash = currentSenderIdStr?.hashCode ?? 0;
                        final grayShades = [
                          Colors.grey[100]!,
                          Colors.grey[200]!,
                          const Color(0xFFF5F5F5),
                          const Color(0xFFEEEEEE),
                          const Color(0xFFE8E8E8),
                        ];
                        final otherUserColor = grayShades[senderHash.abs() % grayShades.length];
                        final messageTime = (() {
                          final created = message['created_at'];
                          if (created == null) return '';
                          try {
                            final dt = DateTime.parse(created.toString()).toLocal();
                            final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
                            final m = dt.minute.toString().padLeft(2, '0');
                            final ampm = dt.hour >= 12 ? 'pm' : 'am';
                            return '$h:$m $ampm';
                          } catch (_) {
                            return created.toString();
                          }
                        })();
                            
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                          alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: IntrinsicWidth(
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                                minWidth: 80,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isCurrentUser ? Colors.black : otherUserColor,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(12, 12, isOwner ? 36 : 12, 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (showSenderName)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4.0),
                                              child: Text(
                                                senderName,
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: isCurrentUser ? Colors.white : Colors.black,
                                                ),
                                              ),
                                            ),
                                          Builder(
                                            builder: (context) {
                                              if (messageText.length > 30) {
                                                // Long message: timestamp below
                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      messageText,
                                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.w300,
                                                        color: isCurrentUser ? Colors.white : Colors.black,
                                                      ),
                                                    ),
                                                    if (messageTime.isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 4.0),
                                                        child: Align(
                                                          alignment: Alignment.centerRight,
                                                          child: Text(
                                                            messageTime,
                                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                                  fontStyle: FontStyle.italic,
                                                                  color: isCurrentUser ? Colors.white70 : Colors.grey[700],
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              } else {
                                                // Short message: timestamp inline
                                                return Row(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        messageText,
                                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                          fontWeight: FontWeight.w300,
                                                          color: isCurrentUser ? Colors.white : Colors.black,
                                                        ),
                                                      ),
                                                    ),
                                                    if (messageTime.isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(left: 8.0),
                                                        child: Text(
                                                          messageTime,
                                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                                fontStyle: FontStyle.italic,
                                                                color: isCurrentUser ? Colors.white70 : Colors.grey[700],
                                                              ),
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isOwner)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      if (value == 'delete') {
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
                                      } else if (value == 'remove_user') {
                                        try {
                                          // Extract sender user id safely
                                          final dynamic sender = message['sender'];
                                          int? senderId;
                                          if (sender is Map) {
                                            final raw = sender['id'] ?? sender['user_id'] ?? sender['uid'];
                                            if (raw is num) senderId = raw.toInt();
                                            if (senderId == null && raw is String) {
                                              final parsed = int.tryParse(raw);
                                              if (parsed != null) senderId = parsed;
                                            }
                                          }
                                          if (senderId == null) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Cannot determine user to remove')),
                                            );
                                            return;
                                          }
                                          final groupsRepo = ref.read(groupsRepositoryProvider);
                                          await groupsRepo.removeMember(groupId, senderId);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Removed user #$senderId from group')),
                                            );
                                          }
                                          messagesNotifier.refresh();
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Failed to remove user: $e')),
                                            );
                                          }
                                        }
                                      }
                                    },
                                    itemBuilder: (ctx) {
                                      // compute sender id to decide if remove is allowed
                                      final dynamic sender = message['sender'];
                                      String? senderIdStr;
                                      if (sender is Map) {
                                        final raw = sender['id'] ?? sender['user_id'] ?? sender['uid'];
                                        if (raw != null) senderIdStr = raw.toString();
                                      }
                                      final ownerIdStr = (normalizedOwnerId ?? '').trim();
                                      final isSenderOwner = senderIdStr != null && senderIdStr.trim() == ownerIdStr;
                                      final items = <PopupMenuEntry<String>>[
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete message'),
                                        ),
                                      ];
                                      if (!isSenderOwner) {
                                        items.add(
                                          const PopupMenuItem(
                                            value: 'remove_user',
                                            child: Text('Remove user from group'),
                                          ),
                                        );
                                      }
                                      return items;
                                    },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                        // Scroll to bottom button with unread count
                        if (_showScrollToBottom)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: FloatingActionButton.small(
                              onPressed: _scrollToBottom,
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Stack(
                                children: [
                                  const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                                  if (messagesNotifier.unreadCount > 0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Text(
                                          '${messagesNotifier.unreadCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
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
              Container(
                color: Colors.black,
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextField(
                          controller: _text,
                          decoration: InputDecoration(
                            hintText: 'Type Message',
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onSubmitted: (_) => _sendMessage(groupId),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.send, color: Colors.black),
                        onPressed: _sending ? null : () => _sendMessage(groupId),
                      ),
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
        final messagesAsync = ref.watch(combinedMessagesProvider(groupId));
        final messagesNotifier = ref.read(combinedMessagesProvider(groupId).notifier);
        
        // Set up new message callback for auto-scroll
        messagesNotifier.setNewMessageCallback(_onNewMessage);

        return Scaffold(
          resizeToAvoidBottomInset: true,
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
              Container(
                color: Colors.black,
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextField(
                          controller: _text,
                          decoration: InputDecoration(
                            hintText: 'Type Message',
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onSubmitted: (_) => _sendMessage(groupId),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.send, color: Colors.black),
                        onPressed: _sending ? null : () => _sendMessage(groupId),
                      ),
                    ),
                  ],
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
      ref.read(combinedMessagesProvider(groupId).notifier).refresh();
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
