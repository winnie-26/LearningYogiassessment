import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/groups_repository.dart';
import '../../data/repositories/users_repository.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _name = TextEditingController();
  bool _private = false; // false => open, true => private
  final _maxMembers = TextEditingController(text: '50');
  bool _loading = false;
  String? _error;
  final _search = TextEditingController();
  final Set<int> _selected = <int>{};

  Future<List<Map<String, dynamic>>> _loadUsers(String q) async {
    final repo = ref.read(usersRepositoryProvider);
    return repo.list(q: q, limit: 100);
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final name = _name.text.trim();
      final type = _private ? 'private' : 'open';
      final maxMembers = int.tryParse(_maxMembers.text.trim()) ?? 50;
      final repo = ref.read(groupsRepositoryProvider);
      final created = await repo.create(name, type, maxMembers, memberIds: _selected.toList());
      // Try to auto-join if API requires membership for listing
      final id = (created['id'] ?? created['group_id']) as int?;
      if (id != null) {
        try { await repo.join(id); } catch (_) {/* ignore */}
      }
      if (!mounted) return;
      Navigator.of(context).pop({'created': true, 'group': created});
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Group')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Settings Section
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Group Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(child: Text('Private (closed group)')),
                  Switch.adaptive(value: _private, onChanged: (v) => setState(() => _private = v)),
                ],
              ),
              const Divider(height: 24),
              // Add Members Section
              const Text('Add Members', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search users',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadUsers(_search.text.trim()),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final users = snap.data ?? const <Map<String, dynamic>>[];
                    if (users.isEmpty) {
                      return const Center(child: Text('No users found'));
                    }
                    return ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final u = users[index];
                        final rawId = u['id'];
                        final id = rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '') ?? -1;
                        final email = (u['email'] ?? '').toString();
                        final selected = _selected.contains(id);
                        return ListTile(
                          title: Text(email),
                          trailing: Checkbox(
                            value: selected,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected.add(id);
                              } else {
                                _selected.remove(id);
                              }
                            }),
                          ),
                          onTap: () => setState(() {
                            if (selected) {
                              _selected.remove(id);
                            } else {
                              _selected.add(id);
                            }
                          }),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
