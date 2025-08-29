import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/groups_repository.dart';

final groupsListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(groupsRepositoryProvider);
  final items = await repo.list(limit: 50);
  // Ensure a list of maps for UI safety (skip non-map items)
  return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
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
                final id = rawId is num ? rawId.toInt() : int.tryParse(rawId.toString()) ?? index;
                final name = g['name']?.toString() ?? 'Group #$id';
                final type = g['type']?.toString();
                final members = g['members'] ?? g['member_count'] ?? g['members_count'];
                final max = g['max_members'] ?? g['capacity'] ?? g['limit'];
                final subtitleParts = <String>[];
                if (type != null && type.isNotEmpty) subtitleParts.add(type);
                if (members != null && max != null) {
                  subtitleParts.add('$members/$max members');
                } else if (members != null) {
                  subtitleParts.add('$members members');
                }
                return ListTile(
                  title: Text(name),
                  subtitle: subtitleParts.isNotEmpty ? Text(subtitleParts.join(' • ')) : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed('/chat', arguments: {'id': id, 'name': name, if (type != null) 'type': type}),
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
