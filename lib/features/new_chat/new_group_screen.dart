import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/widgets/misc.dart';
import '../../data/models/profile.dart';
import '../../data/providers.dart';
import '../chats/chats_provider.dart';
import 'new_chat_screen.dart';

class NewGroupScreen extends ConsumerStatefulWidget {
  const NewGroupScreen({super.key});
  @override
  ConsumerState<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends ConsumerState<NewGroupScreen> {
  final _title = TextEditingController();
  final Map<String, Profile> _members = {};
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showSnack(context, context.tr('required'));
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(conversationRepoProvider)
          .createGroup(title, _members.keys.toList());
      ref.read(chatsRefreshProvider.notifier).state++;
      if (mounted) context.pushReplacement('/chat/$id');
    } catch (_) {
      if (mounted) showSnack(context, context.tr('error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('newGroup')),
        actions: [
          TextButton(
            onPressed: _busy ? null : _create,
            child: Text(context.tr('create'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _title,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: context.tr('groupName'),
              prefixIcon: const Icon(Icons.groups),
            ),
          ),
        ),
        if (_members.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _members.values
                  .map((p) => Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: InputChip(
                          label: Text(p.displayName),
                          onDeleted: () => setState(() => _members.remove(p.id)),
                        ),
                      ))
                  .toList(),
            ),
          ),
        Expanded(
          child: UserSearchList(
            excludeIds: _members.keys.toSet(),
            onPick: (p) => setState(() => _members[p.id] = p),
          ),
        ),
      ]),
    );
  }
}
