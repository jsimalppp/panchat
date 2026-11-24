import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/widgets/misc.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/providers.dart';
import '../../data/repositories/conversation_repository.dart';
import '../new_chat/new_chat_screen.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  const GroupInfoScreen({super.key, required this.conversationId});
  final String conversationId;
  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  List<Member> _members = [];
  String _title = '';
  bool _loading = true;

  String get _me => ref.read(supabaseProvider).auth.currentUser!.id;
  bool get _iAmAdmin => _members.any((m) => m.profile.id == _me && m.isAdmin);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(conversationRepoProvider);
    try {
      final conv = await repo.fetchConversation(widget.conversationId);
      final members = await repo.fetchMembers(widget.conversationId);
      _title = (conv['title'] as String?) ?? '';
      _members = members;
    } catch (_) {
      if (mounted) showSnack(context, context.tr('error'));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (c) => Scaffold(
        appBar: AppBar(title: Text(context.tr('addMember'))),
        body: UserSearchList(
          excludeIds: _members.map((m) => m.profile.id).toSet(),
          onPick: (p) async {
            try {
              await ref.read(conversationRepoProvider).addMember(widget.conversationId, p.id);
              if (c.mounted) Navigator.of(c).pop();
            } catch (_) {
              if (c.mounted) showSnack(c, c.tr('notAdmin'));
            }
          },
        ),
      ),
    ));
    await _load();
  }

  Future<void> _remove(Member m) async {
    try {
      await ref.read(conversationRepoProvider).removeMember(widget.conversationId, m.profile.id);
      await _load();
    } catch (_) {
      if (mounted) showSnack(context, context.tr('notAdmin'));
    }
  }

  Future<void> _leave() async {
    try {
      await ref.read(conversationRepoProvider).leave(widget.conversationId);
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) showSnack(context, context.tr('error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(profileRepoProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_title.isEmpty ? context.tr('group') : _title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('${context.tr('members')} (${_members.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (_iAmAdmin)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_add)),
                  title: Text(context.tr('addMember')),
                  onTap: _add,
                ),
              for (final m in _members)
                ListTile(
                  leading: UserAvatar(name: m.profile.displayName, url: repo.avatarUrl(m.profile.avatarPath)),
                  title: Text(m.profile.displayName),
                  subtitle: Text('@${m.profile.username}${m.isAdmin ? '  •  admin' : ''}'),
                  trailing: (_iAmAdmin && m.profile.id != _me)
                      ? IconButton(
                          icon: const Icon(Icons.person_remove),
                          tooltip: context.tr('remove'),
                          onPressed: () => _remove(m),
                        )
                      : null,
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: Text(context.tr('leave'), style: const TextStyle(color: Colors.red)),
                onTap: _leave,
              ),
            ]),
    );
  }
}
