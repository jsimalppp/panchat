import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/misc.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/chat_summary.dart';
import '../../data/providers.dart';
import '../../data/theme_store.dart';
import 'chats_provider.dart';

class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Text('🐼 '),
          Text(context.tr('chats'), style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode),
            tooltip: context.tr('darkMode'),
            onPressed: () => ref.read(themeModeProvider.notifier).set(
                Theme.of(context).brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newMenu(context),
        child: const Icon(Icons.add_comment),
      ),
      body: chats.when(
        data: (list) {
          if (list.isEmpty) {
            return CenteredMessage(context.tr('noChats'), icon: Icons.chat_bubble_outline);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(chatsProvider),
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (c, i) => const Divider(height: 1, indent: 76),
              itemBuilder: (c, i) => _ChatTile(chat: list[i], myId: ref.read(supabaseProvider).auth.currentUser!.id),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => CenteredMessage(context.tr('error'), icon: Icons.error_outline),
      ),
    );
  }

  void _newMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.person_add),
            title: Text(context.tr('newChat')),
            onTap: () {
              Navigator.pop(c);
              context.push('/new-chat');
            },
          ),
          ListTile(
            leading: const Icon(Icons.group_add),
            title: Text(context.tr('newGroup')),
            onTap: () {
              Navigator.pop(c);
              context.push('/new-group');
            },
          ),
        ]),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.myId});
  final ChatSummary chat;
  final String myId;

  String _preview(BuildContext c) {
    final m = chat.lastMessage;
    if (m == null) return c.tr('sayHi');
    final prefix = m.senderId == myId ? '${c.tr('you')}: ' : '';
    if (m.isDeleted) return c.tr('deleted');
    switch (m.type) {
      case 'image':
        return '$prefix📷 ${c.tr('photo')}';
      case 'voice':
        return '$prefix🎤 ${c.tr('voice')}';
      default:
        return '$prefix${m.body ?? ''}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = chat.unread > 0;
    return ListTile(
      leading: UserAvatar(name: chat.title, url: chat.avatarUrl, isGroup: chat.isGroup),
      title: Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500)),
      subtitle: Text(_preview(context), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatChatTime(chat.lastMessageAt),
              style: TextStyle(fontSize: 12, color: hasUnread ? PandaColors.bamboo : Colors.grey)),
          const SizedBox(height: 4),
          if (hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: PandaColors.bamboo, borderRadius: BorderRadius.circular(12)),
              child: Text(chat.unread > 99 ? '99+' : '${chat.unread}',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
      onTap: () => context.push('/chat/${chat.id}'),
    );
  }
}
