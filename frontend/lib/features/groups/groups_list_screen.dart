import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/groups_repository.dart';
import '../../data/api/api_client.dart';
import '../../data/repositories/messages_repository.dart';

final groupsListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(groupsRepositoryProvider);
  final items = await repo.list(limit: 50);
  // Ensure a list of maps for UI safety (skip non-map items)
  return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
});

// Fetch the most recent message for a group (limit 1)
final lastMessageProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, int>((ref, groupId) async {
  final repo = ref.read(messagesRepositoryProvider);
  try {
    final list = await repo.list(groupId, limit: 20);
    if (list.isEmpty) return null;
    // Prefer the item with the largest created_at, else fall back to the last element
    Map<String, dynamic>? pick;
    DateTime? best;
    for (final item in list) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final ts = map['created_at'] ?? map['timestamp'] ?? map['sent_at'] ?? map['time'];
      if (ts is String) {
        try {
          final dt = DateTime.parse(ts);
          if (best == null || dt.isAfter(best)) {
            best = dt;
            pick = map;
          }
        } catch (_) {}
      }
    }
    pick ??= (list.last is Map ? (list.last as Map).cast<String, dynamic>() : null);
    return pick;
  } catch (_) {}
  return null;
});

class GroupsListScreen extends ConsumerStatefulWidget {
  const GroupsListScreen({super.key});

  @override
  ConsumerState<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends ConsumerState<GroupsListScreen> {
  final _search = TextEditingController();
  final Set<int> _sentRequests = <int>{};

  bool _isJoined(Map<String, dynamic> g) {
    final keys = ['is_member', 'joined', 'membership', 'am_member'];
    for (final k in keys) {
      final v = g[k];
      if (v is bool && v) return true;
      if (v is num && v != 0) return true;
      if (v is String && (v.toLowerCase() == 'true' || v == '1')) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.of(context).pushNamed('/create-group');
              if (result is Map && result['created'] == true) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group created')),
                  );
                }
                ref.invalidate(groupsListProvider);
              }
            },
            tooltip: 'Create group',
          )
        ],
      ),
      body: groupsAsync.when(
        data: (groups) {
          // Filter by search
          final query = _search.text.trim().toLowerCase();
          final filtered = groups.where((g) {
            final name = g['name']?.toString().toLowerCase() ?? '';
            return query.isEmpty || name.contains(query);
          }).toList();
          // Sort: joined first, unjoined last
          filtered.sort((a, b) {
            final aj = _isJoined(a) ? 1 : 0;
            final bj = _isJoined(b) ? 1 : 0;
            if (aj != bj) return bj.compareTo(aj); // 1 before 0
            final an = a['name']?.toString() ?? '';
            final bn = b['name']?.toString() ?? '';
            return an.toLowerCase().compareTo(bn.toLowerCase());
          });

          if (filtered.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async { ref.invalidate(groupsListProvider); await ref.read(groupsListProvider.future); },
              child: ListView(
                children: [
                  _SearchBar(controller: _search, onChanged: (_) => setState(() {})),
                  const SizedBox(height: 200),
                  const Center(child: Text('No groups yet')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async { ref.invalidate(groupsListProvider); await ref.read(groupsListProvider.future); },
            child: ListView.separated(
              itemCount: filtered.length + 1,
              separatorBuilder: (context, index) => index == 0 ? const SizedBox.shrink() : const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _SearchBar(controller: _search, onChanged: (_) => setState(() {}));
                }
                final g = filtered[index - 1];
                final rawId = g['id'] ?? g['group_id'] ?? index;
                // Handle different ID types from backend (could be String or int)
                final id = rawId is int 
                  ? rawId 
                  : rawId is num 
                    ? rawId.toInt() 
                    : int.tryParse(rawId?.toString() ?? '') ?? index;
                final name = g['name']?.toString() ?? 'Group #$id';
                final type = (g['type']?.toString() ?? 'public').toLowerCase();
                final isPrivate = type == 'private';
                // member counts available but not shown in this compact list item design
                
                // Extract last message info robustly
                String? _formatTime(String? iso) {
                  if (iso == null || iso.isEmpty) return null;
                  try {
                    final dt = DateTime.parse(iso).toLocal();
                    final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
                    final mm = dt.minute.toString().padLeft(2, '0');
                    final ampm = dt.hour >= 12 ? 'pm' : 'am';
                    return '$h12:$mm $ampm';
                  } catch (_) {
                    return null;
                  }
                }

                String? lastText;
                String? lastSender;
                String? lastAt;

                final last = g['last_message'] ?? g['lastMessage'] ?? g['latest_message'] ?? g['last'] ?? g['recent_message'];
                if (last is Map) {
                  lastText = (last['text'] ?? last['message'] ?? last['body'] ?? last['content'])?.toString();
                  final sender = last['sender'] ?? last['user'] ?? last['from'];
                  if (sender is Map) {
                    lastSender = (sender['name'] ?? sender['username'] ?? sender['email'])?.toString();
                  } else if (sender is String) {
                    lastSender = sender;
                  }
                  lastAt = (last['created_at'] ?? last['timestamp'] ?? last['sent_at'] ?? last['time'])?.toString();
                } else if (last is String) {
                  lastText = last;
                }
                lastAt ??= (g['last_message_at'] ?? g['updated_at'] ?? g['lastActivityAt'])?.toString();
                final timeLabel = _formatTime(lastAt) ?? '';

                final lastLine = () {
                  final t = lastText?.trim();
                  final s = lastSender?.toString().trim();
                  if (t == null || t.isEmpty) return null;
                  if (s == null || s.isEmpty) return t;
                  return '$s: $t';
                }();

                final lastAsync = ref.watch(lastMessageProvider(id));
                return lastAsync.when(
                  data: (m) {
                    // Prefer API-provided last message, else fallback to group-derived
                    String? fmText = lastText;
                    String? fmSender = lastSender;
                    String? fmAt = lastAt;
                    if (m != null) {
                      fmText = (m['text'] ?? m['message'] ?? m['body'] ?? m['content'])?.toString() ?? fmText;
                      final sender = m['sender'] ?? m['user'] ?? m['from'];
                      if (sender is Map) {
                        fmSender = (sender['name'] ?? sender['username'] ?? sender['email'])?.toString() ?? fmSender;
                      } else if (sender is String) {
                        fmSender = sender;
                      }
                      fmAt = (m['created_at'] ?? m['timestamp'] ?? m['sent_at'] ?? m['time'])?.toString() ?? fmAt;
                    }
                    final fl = () {
                      final t = fmText?.trim();
                      final s = fmSender?.toString().trim();
                      if (t == null || t.isEmpty) return null;
                      if (s == null || s.isEmpty) return t;
                      return '$s: $t';
                    }();
                    final tlabel = _formatTime(fmAt) ?? timeLabel;

                    return ListTile(
                      title: Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: fl != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: Text(
                                      fl,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                  if (tlabel.isNotEmpty)
                                    Expanded(
                                      flex: 3,
                                      child: Align(
                                        alignment: Alignment.topRight,
                                        child: Text(
                                          tlabel,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : tlabel.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      tlabel,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                                    ),
                                  ),
                                )
                              : null,
                      trailing: _sentRequests.contains(id)
                          ? const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Chip(label: Text('Requested')),
                            )
                          : null,
                      onTap: () async {
                        final repo = ref.read(groupsRepositoryProvider);
                        final api = ref.read(apiClientProvider);
                        // If already joined, go straight to chat
                        if (_isJoined(g)) {
                          if (!context.mounted) return;
                          Navigator.of(context).pushNamed(
                            '/chat',
                            arguments: {
                              'id': id,
                              'name': name,
                              'isPrivate': isPrivate,
                              'ownerId': g['owner_id'],
                            },
                          );
                          return;
                        }
                    
                        // Prevent duplicate requests for private groups
                        if (isPrivate && _sentRequests.contains(id)) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Join request already sent')),
                          );
                          return;
                        }
                    
                        try {
                          // Ask backend whether we can join directly
                          final res = await api.canJoinGroup(id);
                          final body = res.data;
                          bool canJoin = false;
                          bool needsInvite = isPrivate;
                          bool isFull = false;
                          if (body is Map) {
                            final map = body.cast<String, dynamic>();
                            canJoin = map['canJoin'] == true || map['allowed'] == true;
                            needsInvite = map['requiresInvite'] == true || map['isPrivate'] == true || map['reason'] == 'invitation_required' || needsInvite;
                            isFull = map['reason'] == 'group_full' || (map['message']?.toString().toLowerCase().contains('maximum') ?? false);
                          }
                    
                          if (isFull) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('This group is full.')),
                            );
                            return;
                          }
                    
                          if (canJoin && !needsInvite) {
                            await repo.join(id);
                            if (!context.mounted) return;
                            Navigator.of(context).pushNamed(
                              '/chat',
                              arguments: {
                                'id': id,
                                'name': name,
                                'isPrivate': isPrivate,
                                'ownerId': g['owner_id'],
                              },
                            );
                            return;
                          }
                    
                          // Private or needs invite: prompt to send join request
                          if (!context.mounted) return;
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Request to join?'),
                              content: Text('"$name" is a private group. Send a join request to the owner?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Send request')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await api.createJoinRequest(id);
                            setState(() { _sentRequests.add(id); });
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Join request sent')),
                            );
                          }
                        } catch (e) {
                          // Fallback: if public, attempt to join; else show prompt
                          if (!isPrivate) {
                            try {
                              await repo.join(id);
                              if (!context.mounted) return;
                              Navigator.of(context).pushNamed(
                                '/chat',
                                arguments: {
                                  'id': id,
                                  'name': name,
                                  'isPrivate': isPrivate,
                                  'ownerId': g['owner_id'],
                                },
                              );
                            } catch (e2) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to join: $e2')),
                              );
                            }
                          } else {
                            if (!context.mounted) return;
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Request to join?'),
                                content: Text('Send a join request to "${name}"?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                  ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Send request')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                final api = ref.read(apiClientProvider);
                                await api.createJoinRequest(id);
                                setState(() { _sentRequests.add(id); });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Join request sent')),
                                );
                              } catch (e3) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to send request: $e3')),
                                );
                              }
                            }
                          }
                        }
                      },
                    );
                  },
                  loading: () {
                    // Show tile without last message/time while loading
                    return ListTile(
                      title: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).pushNamed(
                        '/chat',
                        arguments: {
                          'id': id,
                          'name': name,
                          'isPrivate': isPrivate,
                          'ownerId': g['owner_id'],
                        },
                      ),
                    );
                  },
                  error: (e, st) {
                    // Fallback to previously computed values
                    return ListTile(
                      title: Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: lastLine != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: Text(
                                      lastLine,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                  if (timeLabel.isNotEmpty)
                                    Expanded(
                                      flex: 3,
                                      child: Align(
                                        alignment: Alignment.topRight,
                                        child: Text(
                                          timeLabel,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : timeLabel.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      timeLabel,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                                    ),
                                  ),
                                )
                              : null,
                      onTap: () => Navigator.of(context).pushNamed(
                        '/chat',
                        arguments: {
                          'id': id,
                          'name': name,
                          'isPrivate': isPrivate,
                          'ownerId': g['owner_id'],
                        },
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Failed to load groups', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(e.toString(), style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () { ref.invalidate(groupsListProvider); },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search groups',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(0)),
          isDense: true,
        ),
      ),
    );
  }
}
