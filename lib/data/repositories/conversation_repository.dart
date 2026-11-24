import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_summary.dart';
import '../models/message.dart';
import '../models/profile.dart';

class ConversationRepository {
  ConversationRepository(this.client);
  final SupabaseClient client;

  String get myId => client.auth.currentUser!.id;

  Future<String> createDirect(String otherId) async {
    final res = await client.rpc('create_direct_conversation', params: {'other': otherId});
    return res as String;
  }

  Future<String> createGroup(String title, List<String> memberIds) async {
    final res = await client.rpc('create_group_conversation',
        params: {'group_title': title, 'member_ids': memberIds});
    return res as String;
  }

  Future<void> addMember(String convId, String memberId) =>
      client.rpc('add_group_member', params: {'conv': convId, 'member': memberId});

  Future<void> removeMember(String convId, String memberId) =>
      client.rpc('remove_group_member', params: {'conv': convId, 'member': memberId});

  Future<void> leave(String convId) =>
      client.from('participants').delete().eq('conversation_id', convId).eq('user_id', myId);

  Future<void> markRead(String convId) =>
      client.rpc('mark_conversation_read', params: {'conv': convId});

  String? _avatarUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return client.storage.from('avatars').getPublicUrl(path);
  }

  /// Members of a conversation with their profiles and roles.
  Future<List<Member>> fetchMembers(String convId) async {
    final rows = await client
        .from('participants')
        .select('user_id, role, profiles(*)')
        .eq('conversation_id', convId);
    return List<Map<String, dynamic>>.from(rows).map((r) {
      return Member(
        profile: Profile.fromJson(Map<String, dynamic>.from(r['profiles'] as Map)),
        isAdmin: r['role'] == 'admin',
      );
    }).toList();
  }

  Future<Map<String, dynamic>> fetchConversation(String convId) async {
    return await client.from('conversations').select().eq('id', convId).single();
  }

  /// Chat list: my conversations, last message and unread count.
  Future<List<ChatSummary>> fetchChats() async {
    final mine = List<Map<String, dynamic>>.from(await client
        .from('participants')
        .select(
            'conversation_id, last_read_at, conversations(id, type, title, avatar_path, last_message_at)')
        .eq('user_id', myId));
    if (mine.isEmpty) return [];
    final ids = mine.map((r) => r['conversation_id'] as String).toList();

    final others = List<Map<String, dynamic>>.from(await client
        .from('participants')
        .select('conversation_id, user_id, profiles(*)')
        .inFilter('conversation_id', ids)
        .neq('user_id', myId));
    final otherByConv = <String, Profile>{};
    for (final o in others) {
      final cid = o['conversation_id'] as String;
      otherByConv.putIfAbsent(
          cid, () => Profile.fromJson(Map<String, dynamic>.from(o['profiles'] as Map)));
    }

    final summaries = await Future.wait(mine.map((r) async {
      final conv = Map<String, dynamic>.from(r['conversations'] as Map);
      final cid = conv['id'] as String;
      final lastRead = r['last_read_at'] as String;
      final last = List<Map<String, dynamic>>.from(await client
          .from('messages')
          .select()
          .eq('conversation_id', cid)
          .order('created_at', ascending: false)
          .limit(1));
      final unreadRows = List<Map<String, dynamic>>.from(await client
          .from('messages')
          .select('id')
          .eq('conversation_id', cid)
          .neq('sender_id', myId)
          .gt('created_at', lastRead)
          .limit(100));
      final isGroup = conv['type'] == 'group';
      final other = otherByConv[cid];
      return ChatSummary(
        id: cid,
        isGroup: isGroup,
        title: isGroup ? (conv['title'] as String? ?? '') : (other?.displayName ?? '?'),
        avatarUrl: isGroup ? _avatarUrl(conv['avatar_path'] as String?) : _avatarUrl(other?.avatarPath),
        other: other,
        lastMessage: last.isEmpty ? null : Message.fromJson(last.first),
        unread: unreadRows.length,
        lastMessageAt: DateTime.parse(conv['last_message_at'] as String),
      );
    }));
    summaries.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return summaries;
  }
}

class Member {
  Member({required this.profile, required this.isAdmin});
  final Profile profile;
  final bool isAdmin;
}
