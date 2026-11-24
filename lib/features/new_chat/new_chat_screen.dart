import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/utils/debouncer.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/misc.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/profile.dart';
import '../../data/providers.dart';
import '../chats/chats_provider.dart';

/// Reusable username search list.
class UserSearchList extends ConsumerStatefulWidget {
  const UserSearchList({super.key, required this.onPick, this.excludeIds = const {}});
  final void Function(Profile p) onPick;
  final Set<String> excludeIds;
  @override
  ConsumerState<UserSearchList> createState() => _UserSearchListState();
}

class _UserSearchListState extends ConsumerState<UserSearchList> {
  final _deb = Debouncer(const Duration(milliseconds: 350));
  final _ctrl = TextEditingController();
  List<Profile> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _deb.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _deb.run(() async {
      final q = sanitizeUsernameQuery(v.replaceAll('@', ''));
      if (q.isEmpty) {
        if (mounted) setState(() { _results = []; _searched = false; });
        return;
      }
      setState(() => _loading = true);
      try {
        final r = await ref.read(profileRepoProvider).search(q);
        if (mounted) setState(() { _results = r; _searched = true; });
      } catch (_) {
        if (mounted) showSnack(context, context.tr('error'));
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(profileRepoProvider);
    final shown = _results.where((p) => !widget.excludeIds.contains(p.id)).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _ctrl,
          autocorrect: false,
          autofocus: true,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: context.tr('searchUsername'),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
      ),
      if (_loading) const LinearProgressIndicator(),
      Expanded(
        child: (_searched && shown.isEmpty)
            ? CenteredMessage(context.tr('noResults'), icon: Icons.person_search)
            : ListView.builder(
                itemCount: shown.length,
                itemBuilder: (c, i) {
                  final p = shown[i];
                  return ListTile(
                    leading: UserAvatar(name: p.displayName, url: repo.avatarUrl(p.avatarPath)),
                    title: Text(p.displayName),
                    subtitle: Text('@${p.username}'),
                    onTap: () => widget.onPick(p),
                  );
                },
              ),
      ),
    ]);
  }
}

class NewChatScreen extends ConsumerWidget {
  const NewChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('newChat'))),
      body: Column(children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.group_add)),
          title: Text(context.tr('newGroup')),
          onTap: () => context.pushReplacement('/new-group'),
        ),
        const Divider(height: 1),
        Expanded(
          child: UserSearchList(
            onPick: (p) async {
              try {
                final id = await ref.read(conversationRepoProvider).createDirect(p.id);
                ref.read(chatsRefreshProvider.notifier).state++;
                if (context.mounted) context.pushReplacement('/chat/$id');
              } catch (_) {
                if (context.mounted) showSnack(context, context.tr('error'));
              }
            },
          ),
        ),
      ]),
    );
  }
}
