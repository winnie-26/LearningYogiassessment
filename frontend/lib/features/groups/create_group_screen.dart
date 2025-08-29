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
  String _groupType = 'public'; // 'public' or 'private'
  bool _loading = false;
  String? _error;
  final _search = TextEditingController();
  final Set<int> _selected = <int>{};

  Future<List<Map<String, dynamic>>> _loadUsers(String q) async {
    final repo = ref.read(usersRepositoryProvider);
    final response = await repo.list(q: q, limit: 100);
    
    // Extract and sort users alphabetically by name
    final users = response.items.toList()..sort((a, b) {
      final nameA = (a['name'] ?? a['email'] ?? '').toString().toLowerCase();
      final nameB = (b['name'] ?? b['email'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });
    
    return users;
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final name = _name.text.trim();
      final type = _groupType; // 'public' or 'private'
      const maxMembers = 50; // default max users
      final repo = ref.read(groupsRepositoryProvider);
      final created = await repo.create(name, type, maxMembers, memberIds: _selected.toList());
      // Try to auto-join if API requires membership for listing
      final dynamic rawId = created['id'] ?? created['group_id'];
      final int? id = rawId is int 
          ? rawId 
          : rawId is num 
              ? rawId.toInt() 
              : int.tryParse(rawId?.toString() ?? '');
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
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Group',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Info Card
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    // Group Name
                    TextField(
                      controller: _name,
                      style: theme.textTheme.titleMedium,
                      decoration: InputDecoration(
                        hintText: 'Group Name',
                        hintStyle: theme.textTheme.bodyMedium,
                        filled: true,
                        fillColor: theme.cardColor,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Colors.black, width: 1),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Colors.black, width: 1),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Colors.black, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Group Type Selection
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Private (closed group)',
                          style: theme.textTheme.bodyLarge,
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _groupType = _groupType == 'private' ? 'public' : 'private';
                            });
                          },
                          child: Container(
                            width: 100,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _groupType == 'private' ? Colors.black : Colors.grey[300],
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Stack(
                              children: [
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 200),
                                  left: _groupType == 'private' ? 2 : 52,
                                  top: 2,
                                  child: Container(
                                    width: 46,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _groupType == 'private' ? 'YES' : 'NO',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _groupType == 'private' 
                          ? 'Private groups require invitations to join.'
                          : 'Anyone can join public groups.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ), // End of Group Info Card

              // Add Members Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Members', style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Search users',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                        prefixIcon: Icon(Icons.search, color: theme.iconTheme.color?.withOpacity(0.7)),
                        filled: true,
                        fillColor: theme.cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 300, // or another appropriate height
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadUsers(_search.text.trim()),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Error loading users',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      );
                    }
                    final users = snap.data ?? [];
                    if (users.isEmpty) {
                      return Center(
                        child: Text(
                          'No users found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: users.length,
                      itemBuilder: (ctx, i) {
                        final user = users[i];
                        final String displayName = ((user['name'] ?? user['email']) ?? '').toString();
                        final String letter = displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '#';
                        String? prevLetter;
                        if (i > 0) {
                          final prev = users[i - 1];
                          final prevName = ((prev['name'] ?? prev['email']) ?? '').toString();
                          prevLetter = prevName.isNotEmpty ? prevName[0].toUpperCase() : '#';
                        }
                        final bool isHeader = i == 0 || letter != prevLetter;
                        final dynamic rawId = user['id'];
                        final int? userId = rawId is int
                            ? rawId
                            : rawId is num
                                ? rawId.toInt()
                                : int.tryParse(rawId?.toString() ?? '');
                        final selected = userId != null && _selected.contains(userId);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isHeader)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                                child: Text(
                                  letter,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                              child: InkWell(
                                onTap: () => setState(() {
                                  if (userId == null) return;
                                  if (selected) {
                                    _selected.remove(userId);
                                  } else {
                                    _selected.add(userId);
                                  }
                                }),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            (user['name'] ?? user['email'] ?? '').toString(),
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            selected
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_unchecked,
                                            color: Colors.black,
                                            size: 26,
                                          ),
                                          onPressed: () => setState(() {
                                            if (userId == null) return;
                                            if (selected) {
                                              _selected.remove(userId);
                                            } else {
                                              _selected.add(userId);
                                            }
                                          }),
                                        ),
                                      ],
                                    ),
                                    
                                  ],
                                ),
                              ),
                            ),
                            const Divider(color: Colors.black, thickness: 1, height: 1, indent: 12, endIndent: 12),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Create Group',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
