import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/groups_repository.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _name = TextEditingController();
  String _type = 'open';
  final _maxMembers = TextEditingController(text: '50');
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final name = _name.text.trim();
      final type = _type;
      final maxMembers = int.tryParse(_maxMembers.text.trim()) ?? 50;
      final repo = ref.read(groupsRepositoryProvider);
      final created = await repo.create(name, type, maxMembers);
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          DropdownButton<String>(value: _type, items: const [
            DropdownMenuItem(value: 'open', child: Text('Open')),
            DropdownMenuItem(value: 'private', child: Text('Private')),
          ], onChanged: (v) => setState(() => _type = v ?? 'open')),
          TextField(controller: _maxMembers, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max members')),
          const SizedBox(height: 12),
          if (_error != null) Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
          ),
        ]),
      ),
    );
  }
}
