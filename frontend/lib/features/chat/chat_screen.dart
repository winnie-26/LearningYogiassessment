import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/messages_repository.dart';

final messagesListProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, int>((ref, groupId) async {
  final repo = ref.read(messagesRepositoryProvider);
  final items = await repo.list(groupId, limit: 50);
  return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final rawId = args?['id'] ?? 0;
    final groupId = rawId is num ? rawId.toInt() : int.tryParse(rawId.toString()) ?? 0;
    final name = args?['name']?.toString() ?? 'Chat';
    final type = args?['type']?.toString();
    final msgsAsync = ref.watch(messagesListProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          if (type != null && type.toLowerCase() == 'private')
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add/Invite members',
              onPressed: () {
                // Navigate to a future addMembers screen or show a snackbar for now
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite members coming soon')),
                );
              },
            )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: msgsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async { ref.invalidate(messagesListProvider(groupId)); await ref.read(messagesListProvider(groupId).future); },
                      child: ListView(children: const [SizedBox(height: 200), Center(child: Text('No messages yet'))]),
                    );
                  }
                  // Sort by created_at ascending
                  items.sort((a, b) => (a['created_at'] ?? '').toString().compareTo((b['created_at'] ?? '').toString()));
                  return RefreshIndicator(
                    onRefresh: () async { ref.invalidate(messagesListProvider(groupId)); await ref.read(messagesListProvider(groupId).future); },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final m = items[index];
                        final text = m['text']?.toString() ?? '';
                        final time = (m['created_at']?.toString() ?? '').replaceFirst('T', ' ').replaceFirst('Z', '');
                        final mine = false; // Without user id context, keep neutral styling
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: mine ? Colors.indigo.shade100 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 3)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(text),
                                const SizedBox(height: 4),
                                Text(time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Failed to load messages\n$e', textAlign: TextAlign.center)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      decoration: InputDecoration(
                        hintText: 'Type Message',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _sending ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                    onPressed: _sending ? null : () async {
                      final text = _text.text.trim();
                      if (text.isEmpty) return;
                      setState(() { _sending = true; });
                      try {
                        final repo = ref.read(messagesRepositoryProvider);
                        await repo.send(groupId, text);
                        _text.clear();
                        ref.invalidate(messagesListProvider(groupId));
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e')));
                        }
                      } finally {
                        if (mounted) setState(() { _sending = false; });
                      }
                    },
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
