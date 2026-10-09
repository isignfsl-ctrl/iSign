import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_firebase_service.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/skeleton_loader.dart';

String _relativeTime(String iso) {
  try {
    final dt = DateTime.parse(iso);
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  } catch (_) {
    return iso.length > 10 ? iso.substring(0, 10) : iso;
  }
}

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _fb = AdminFirebaseService();
  final _searchCtl = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = v.toLowerCase());
    });
  }

  Future<void> _inviteUser() async {
    final emailCtl = TextEditingController();
    String selectedRole = 'contributor';

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Invite User'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Create the user in Firebase Console (Authentication > Users > Add user) first, then set their role here.',
                      style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 16),
                  TextField(
                      controller: emailCtl,
                      decoration: const InputDecoration(
                          labelText: 'Email', hintText: 'user@example.com'),
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(
                          value: 'reviewer', child: Text('Reviewer')),
                      DropdownMenuItem(
                          value: 'contributor', child: Text('Contributor')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => selectedRole = v ?? 'contributor'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Invite')),
              ],
            );
          },
        );
      },
    );

    if (created == true && mounted) {
      final email = emailCtl.text.trim();
      if (email.isEmpty) return;

      try {
        final existing = await _fb.firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          await _fb.firestore
              .collection('users')
              .doc(existing.docs.first.id)
              .update({
            'role': selectedRole,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        } else {
          await _fb.firestore.collection('users').add({
            'email': email,
            'role': selectedRole,
            'createdAt': DateTime.now().toIso8601String(),
            'devices': [],
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Invited $email as $selectedRole'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }

  Future<void> _deleteUser(String uid, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove user?'),
        content: Text(
            'Remove $email from the user list?\n\nThis deletes their profile '
            'from Firestore. Their login account continues to exist and they '
            'may still sign in. Use the delete_user.js script for full removal.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _fb.firestore.collection('users').doc(uid).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Removed $email'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'Invite user',
              onPressed: _inviteUser),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by email or UID...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtl.clear();
                          _onSearchChanged('');
                        })
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _fb.firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: List.generate(
                        4,
                        (_) => const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: SkeletonCard(
                                height: 72, lineCount: 2, hasAvatar: true))),
                  );
                }

                var docs = snapshot.data!.docs;
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final id = d.id.toLowerCase();
                    final email =
                        (data['email'] as String? ?? '').toLowerCase();
                    return id.contains(_searchQuery) ||
                        email.contains(_searchQuery);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (snapshot.data!.docs.isEmpty) ...[
                        const SizedBox(height: 8),
                        Card(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.3),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      'Use the + button to invite users. First create the user in Firebase Console (Authentication > Users > Add user).',
                                      style: theme.textTheme.bodySmall)),
                            ]),
                          ),
                        ),
                      ],
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: EmptyStateWidget(
                            icon: Icons.people_outline,
                            title: snapshot.data!.docs.isEmpty
                                ? 'No users yet.'
                                : 'No users match your search.',
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) =>
                      _buildUserCard(context, theme, docs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(
      BuildContext context, ThemeData theme, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final uid = doc.id;
    final email = data['email'] as String? ?? 'Unknown';
    final role = data['role'] as String? ?? 'contributor';
    final createdAt = data['createdAt'] as String? ?? '';
    final devices =
        (data['devices'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    final lastActive = data['lastActive'] as String? ?? '';
    final isAdmin = role == 'admin';
    final avatarLetter = email.isNotEmpty ? email[0].toUpperCase() : '?';
    final isOnline = lastActive.isNotEmpty
        ? DateTime.now()
                .toUtc()
                .difference(DateTime.parse(lastActive).toUtc())
                .inMinutes <
            5
        : false;
    final isSelf = uid == _fb.auth.currentUser?.uid;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isAdmin
                  ? Colors.amber.withValues(alpha: 0.2)
                  : theme.colorScheme.primaryContainer,
              child: Text(avatarLetter,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isAdmin
                          ? Colors.amber.shade700
                          : theme.colorScheme.primary,
                      fontSize: 16)),
            ),
            if (isOnline)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: theme.colorScheme.surface, width: 2)),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
                child: Text(email,
                    style: theme.textTheme.bodyLarge,
                    overflow: TextOverflow.ellipsis)),
            if (isAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('ADMIN',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309))),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Text('${devices.length} device${devices.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall),
            if (createdAt.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text('\u00B7 invited ${_relativeTime(createdAt)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoleDropdown(uid: uid, currentRole: role, fb: _fb),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Remove user (Firestore only)',
              color: theme.colorScheme.error,
              onPressed: isSelf ? null : () => _deleteUser(uid, email),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleDropdown extends StatefulWidget {
  final String uid;
  final String currentRole;
  final AdminFirebaseService fb;
  const _RoleDropdown(
      {required this.uid, required this.currentRole, required this.fb});

  @override
  State<_RoleDropdown> createState() => _RoleDropdownState();
}

class _RoleDropdownState extends State<_RoleDropdown> {
  String? _pendingRole;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: _pendingRole ?? widget.currentRole,
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(
            value: 'admin',
            child: Text('Admin', style: TextStyle(fontSize: 13))),
        DropdownMenuItem(
            value: 'reviewer',
            child: Text('Reviewer', style: TextStyle(fontSize: 13))),
        DropdownMenuItem(
            value: 'contributor',
            child: Text('Contributor', style: TextStyle(fontSize: 13))),
      ],
      onChanged: (newRole) async {
        if (newRole == null || newRole == widget.currentRole) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Change role?'),
            content:
                Text('Change role from "${widget.currentRole}" to "$newRole"?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Change')),
            ],
          ),
        );
        if (confirm == true) {
          await widget.fb.firestore
              .collection('users')
              .doc(widget.uid)
              .update({'role': newRole});
          if (!context.mounted) return;
          setState(() => _pendingRole = newRole);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Changed role to "$newRole"'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
    );
  }
}
