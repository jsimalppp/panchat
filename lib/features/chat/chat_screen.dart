import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/misc.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/message.dart';
import '../../data/providers.dart';
import '../chats/chats_provider.dart';
import 'chat_controller.dart';
import 'composer.dart';
import 'message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});
  final String conversationId;
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  late final ChatController _c;
  late final StateController<int> _refresh;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh = ref.read(chatsRefreshProvider.notifier);
    _c = ChatController(
      onActivity: () { if (mounted) _refresh.state++; },
      conversationId: widget.conversationId,
      client: ref.read(supabaseProvider),
      convRepo: ref.read(conversationRepoProvider),
      mediaRepo: ref.read(mediaRepoProvider),
    )..init();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _c.loadMore();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _c.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    _c.dispose();
    final r = _refresh;
    Future.microtask(() => r.state++);
    super.dispose();
  }

  String _subtitle(BuildContext context) {
    if (_c.typing.isNotEmpty) {
      if (_c.isGroup) {
        final n = _c.members[_c.typing.first]?.displayName ?? '';
        return '$n ${context.tr('typing')}';
      }
      return context.tr('typing');
    }
    if (_c.isGroup) return '${_c.members.length} ${context.tr('members')}';
    final o = _c.other;
    if (o == null) return '';
    if (_c.online.contains(o.id)) return context.tr('online');
    final seen = o.lastSeenAt;
    if (seen == null) return '';
    return '${context.tr('lastSeen')} ${DateFormat('dd/MM HH:mm').format(seen.toLocal())}';
  }

  void _messageMenu(Message m) {
    if (m.isDeleted || m.pending) return;
    final mine = m.senderId == _c.me;
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.reply),
            title: Text(context.tr('reply')),
            onTap: () {
              Navigator.pop(c);
              _c.setReply(m);
            },
          ),
          if (mine)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(context.tr('delete')),
              onTap: () {
                Navigator.pop(c);
                _c.deleteForEveryone(m);
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileRepo = ref.watch(profileRepoProvider);
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final other = _c.other;
        final titleText = _c.isGroup ? _c.title : (other?.displayName ?? '');
        final avatarUrl = _c.isGroup ? null : profileRepo.avatarUrl(other?.avatarPath);
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: InkWell(
              onTap: _c.isGroup ? () => context.push('/group/${widget.conversationId}') : null,
              child: Row(children: [
                UserAvatar(name: titleText, url: avatarUrl, radius: 18, isGroup: _c.isGroup),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titleText, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17)),
                      Text(_subtitle(context), maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          body: Column(children: [
            Expanded(child: _body(context)),
            if (_c.replyingTo != null) _replyBar(context),
            Composer(
              onSendText: _c.sendText,
              onSendImage: _c.sendImage,
              onSendVoice: _c.sendVoice,
              onTyping: _c.notifyTyping,
            ),
          ]),
        );
      },
    );
  }

  Widget _replyBar(BuildContext context) {
    final r = _c.replyingTo!;
    final text = r.type == 'image'
        ? '📷 ${context.tr('photo')}'
        : r.type == 'voice'
            ? '🎤 ${context.tr('voice')}'
            : (r.body ?? '');
    return Container(
      color: PandaColors.bambooSoft.withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        const Icon(Icons.reply, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
        IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _c.setReply(null)),
      ]),
    );
  }

  Widget _body(BuildContext context) {
    if (_c.loading) return const Center(child: CircularProgressIndicator());
    if (_c.failed) return CenteredMessage(context.tr('error'), icon: Icons.error_outline);
    if (_c.messages.isEmpty) return CenteredMessage(context.tr('sayHi'));
    final msgs = _c.messages;
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: msgs.length + (_c.loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= msgs.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final m = msgs[i];
        final mine = m.senderId == _c.me;
        return MessageBubble(
          message: m,
          isMine: mine,
          status: mine ? _c.statusOf(m) : 0,
          mediaRepo: _c.mediaRepo,
          senderName: _c.isGroup ? _c.members[m.senderId]?.displayName : null,
          replied: _c.findById(m.replyTo),
          onLongPress: () => _messageMenu(m),
          onRetry: () => _c.retry(m),
        );
      },
    );
  }
}
