import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/groups_repository.dart';
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

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
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
                            if (tlabel.isNotEmpty)
                              Text(
                                tlabel,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                              ),
                          ],
                        ),
                        subtitle: fl != null
                            ? Padding(
                                padding: const EdgeInsets.only(left: 0.0, top: 2.0),
                                child: Text(
                                  fl,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
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
                      ),
                    );
                  },
                  loading: () {
                    // Show tile without last message/time while loading
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
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
                      ),
                    );
                  },
                  error: (e, st) {
                    // Fallback to previously computed values
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
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
                            if (timeLabel.isNotEmpty)
                              Text(
                                timeLabel,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                              ),
                          ],
                        ),
                        subtitle: lastLine != null
                            ? Padding(
                                padding: const EdgeInsets.only(left: 0.0, top: 2.0),
                                child: Text(
                                  lastLine,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
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
      floatingActionButton: FloatingActionButton.extended(
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
        icon: const Icon(Icons.add),
        label: const Text('Create'),
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
        ),
      ),
    );
  }
}
