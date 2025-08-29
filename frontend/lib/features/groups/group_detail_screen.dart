import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  final _emailController = TextEditingController();
  bool _isAdmin = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    if (_emailController.text.trim().isEmpty) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // TODO: Lookup user by email and send invite
      // For now, we'll just show a success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent')),
        );
        _emailController.clear();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final groupId = args['id'] as int? ?? 0;
    final groupName = args['name'] as String? ?? 'Group #$groupId';
    final isPrivate = args['isPrivate'] as bool? ?? false;
    
    // In a real app, you would fetch this from the server
    _isAdmin = true; // For demo purposes

    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
        actions: [
          if (_isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // TODO: Navigate to group settings
              },
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPrivate ? Icons.lock_outline : Icons.public,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPrivate ? 'Private Group' : 'Public Group',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Add more group info here
                    // e.g., member count, description, etc.
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Invite Section (only for admins)
            if (_isAdmin) ...[
              const Text(
                'Invite Members',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter email to invite',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _sendInvite,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Invite'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
            ],

            // Pending Invites Section
            if (_isAdmin)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pending Invitations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // TODO: List pending invites
                  const Text('No pending invitations'),
                  const SizedBox(height: 24),
                ],
              ),

            // Members Section
            const Text(
              'Members',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // TODO: List group members
            const ListTile(
              leading: CircleAvatar(child: Icon(Icons.person)),
              title: Text('You'),
              subtitle: Text('Admin'),
            ),
          ],
        ),
      ),
    );
  }
}
