import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/message.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/media_repository.dart';

const _uuid = Uuid();
const _pageSize = 30;

/// Holds all state for one conversation: messages (newest first), members,
/// read receipts, presence and typing. Created and disposed by ChatScreen.
class ChatController extends ChangeNotifier {
  ChatController({
    required this.conversationId,
    required this.client,
    required this.convRepo,
    required this.mediaRepo,
    this.onActivity,
  });

  /// Called after sending, receiving or marking read, so the chat list refreshes.
  final VoidCallback? onActivity;

  final String conversationId;
  final SupabaseClient client;
  final ConversationRepository convRepo;
  final MediaRepository mediaRepo;

  String get me => client.auth.currentUser!.id;

  List<Message> messages = []; // newest first
  Map<String, Profile> members = {};
  Set<String> adminIds = {};
  Map<String, Set<String>> reads = {}; // messageId -> userIds who read it
  Set<String> online = {};
  final Set<String> typing = {};
  bool isGroup = false;
  String title = '';
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  bool failed = false;
  Message? replyingTo;

  RealtimeChannel? _dbChannel;
  RealtimeChannel? _liveChannel; // private: presence + typing broadcast
  final Map<String, Timer> _typingTimers = {};
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  Profile? get other => isGroup
      ? null
      : members.values.cast<Profile?>().firstWhere((p) => p!.id != me, orElse: () => null);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ------------------------------------------------------------- init
  Future<void> init() async {
    try {
      final conv = await convRepo.fetchConversation(conversationId);
      isGroup = conv['type'] == 'group';
      title = (conv['title'] as String?) ?? '';
      final ms = await convRepo.fetchMembers(conversationId);
      members = {for (final m in ms) m.profile.id: m.profile};
      adminIds = {for (final m in ms) if (m.isAdmin) m.profile.id};
      await _loadLatest();
      _subscribe();
      unawaited(markRead());
    } catch (_) {
      failed = true;
    }
    loading = false;
    _notify();
  }

  Future<void> _loadLatest() async {
    final rows = List<Map<String, dynamic>>.from(await client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(_pageSize));
    final fetched = rows.map(Message.fromJson).toList();
    final ids = fetched.map((m) => m.id).toSet();
    // Keep local pending/failed messages the server does not know about yet.
    final localOnly = messages.where((m) => (m.pending || m.failed) && !ids.contains(m.id));
    messages = [...localOnly, ...fetched]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    hasMore = fetched.length >= _pageSize;
    await _loadReads(fetched.where((m) => m.senderId == me).map((m) => m.id).toList());
  }

  /// Called when the app returns to the foreground to catch missed events.
  Future<void> refresh() async {
    try {
      await _loadLatest();
      _notify();
      unawaited(markRead());
    } catch (_) {}
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore || messages.isEmpty) return;
    loadingMore = true;
    _notify();
    try {
      final oldest = messages.where((m) => !m.pending).last;
      final rows = List<Map<String, dynamic>>.from(await client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .lt('created_at', oldest.createdAt.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(_pageSize));
      final older = rows.map(Message.fromJson).toList();
      hasMore = older.length >= _pageSize;
      messages = [...messages, ...older];
      await _loadReads(older.where((m) => m.senderId == me).map((m) => m.id).toList());
    } catch (_) {}
    loadingMore = false;
    _notify();
  }

  Future<void> _loadReads(List<String> myMessageIds) async {
    if (myMessageIds.isEmpty) return;
    final rows = List<Map<String, dynamic>>.from(await client
        .from('message_reads')
        .select('message_id, user_id')
        .eq('conversation_id', conversationId)
        .inFilter('message_id', myMessageIds));
    for (final r in rows) {
      reads.putIfAbsent(r['message_id'] as String, () => <String>{}).add(r['user_id'] as String);
    }
  }

  // ------------------------------------------------------------- realtime
  void _subscribe() {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'conversation_id',
      value: conversationId,
    );
    _dbChannel = client
        .channel('db:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: filter,
          callback: (p) => _onMessageRow(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: filter,
          callback: (p) => _onMessageRow(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'message_reads',
          filter: filter,
          callback: (p) {
            final r = p.newRecord;
            final mid = r['message_id'] as String?;
            final uid = r['user_id'] as String?;
            if (mid == null || uid == null) return;
            reads.putIfAbsent(mid, () => <String>{}).add(uid);
            _notify();
          },
        )
        .subscribe();

    // Private channel: authorised by the Realtime policies on 'conv:<id>'.
    final live = client.channel(
      'conv:$conversationId',
      opts: RealtimeChannelConfig(key: me, private: true),
    );
    live
        .onPresenceSync((_) => _syncPresence())
        .onPresenceJoin((_) => _syncPresence())
        .onPresenceLeave((_) => _syncPresence())
        .onBroadcast(event: 'typing', callback: (payload) {
          final uid = payload['user_id'] as String?;
          if (uid == null || uid == me) return;
          typing.add(uid);
          _typingTimers[uid]?.cancel();
          _typingTimers[uid] = Timer(const Duration(seconds: 4), () {
            typing.remove(uid);
            _notify();
          });
          _notify();
        })
        .subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        live.track({'user_id': me});
      }
    });
    _liveChannel = live;
  }

  void _syncPresence() {
    final ids = <String>{};
    for (final state in _liveChannel?.presenceState() ?? <SinglePresenceState>[]) {
      for (final p in state.presences) {
        final uid = p.payload['user_id'] as String?;
        if (uid != null) ids.add(uid);
      }
    }
    online = ids;
    _notify();
  }

  void _onMessageRow(Map<String, dynamic> row) {
    if (row.isEmpty) return;
    final msg = Message.fromJson(row);
    final i = messages.indexWhere((m) => m.id == msg.id);
    if (i >= 0) {
      messages[i] = msg; // replaces optimistic copy, applies soft deletes
    } else {
      messages.insert(0, msg);
      messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    if (msg.senderId != me) unawaited(markRead());
    _notify();
  }

  Future<void> markRead() async {
    try {
      await convRepo.markRead(conversationId);
      onActivity?.call();
    } catch (_) {}
  }

  // ------------------------------------------------------------- typing
  void notifyTyping() {
    final now = DateTime.now();
    if (now.difference(_lastTypingSent) < const Duration(seconds: 2)) return;
    _lastTypingSent = now;
    _liveChannel?.sendBroadcastMessage(event: 'typing', payload: {'user_id': me});
  }

  // ------------------------------------------------------------- sending
  void setReply(Message? m) {
    replyingTo = m;
    _notify();
  }

  Future<void> sendText(String text) async {
    final body = text.trim();
    if (body.isEmpty) return;
    final msg = Message(
      id: _uuid.v4(),
      conversationId: conversationId,
      senderId: me,
      type: 'text',
      body: body,
      replyTo: replyingTo?.id,
      createdAt: DateTime.now(),
      pending: true,
    );
    replyingTo = null;
    await _send(msg);
  }

  Future<void> sendImage(Uint8List bytes, String ext) async {
    final id = _uuid.v4();
    try {
      final path = await mediaRepo.upload(
        conversationId: conversationId,
        fileId: id,
        bytes: bytes,
        ext: ext,
        contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
      );
      await _send(Message(
        id: id,
        conversationId: conversationId,
        senderId: me,
        type: 'image',
        mediaPath: path,
        replyTo: replyingTo?.id,
        createdAt: DateTime.now(),
        pending: true,
      ));
      replyingTo = null;
    } catch (_) {
      _notify();
      rethrow;
    }
  }

  Future<void> sendVoice(String filePath, int durationMs) async {
    final id = _uuid.v4();
    final bytes = await File(filePath).readAsBytes();
    final path = await mediaRepo.upload(
      conversationId: conversationId,
      fileId: id,
      bytes: bytes,
      ext: 'm4a',
      contentType: 'audio/mp4',
    );
    await _send(Message(
      id: id,
      conversationId: conversationId,
      senderId: me,
      type: 'voice',
      mediaPath: path,
      durationMs: durationMs.clamp(1, 300000),
      createdAt: DateTime.now(),
      pending: true,
    ));
    try {
      await File(filePath).delete();
    } catch (_) {}
  }

  /// Optimistic insert with a client UUID, so retries are idempotent.
  Future<void> _send(Message msg) async {
    final i = messages.indexWhere((m) => m.id == msg.id);
    if (i >= 0) {
      messages[i] = msg;
    } else {
      messages.insert(0, msg);
    }
    _notify();
    try {
      await client.from('messages').insert(msg.toInsertJson());
      final j = messages.indexWhere((m) => m.id == msg.id);
      if (j >= 0) messages[j] = messages[j].copyWith(pending: false);
    } on PostgrestException catch (e) {
      final j = messages.indexWhere((m) => m.id == msg.id);
      if (e.code == '23505') {
        // Already inserted by an earlier attempt: treat as sent.
        if (j >= 0) messages[j] = messages[j].copyWith(pending: false, failed: false);
      } else if (j >= 0) {
        messages[j] = messages[j].copyWith(pending: false, failed: true);
      }
    } catch (_) {
      final j = messages.indexWhere((m) => m.id == msg.id);
      if (j >= 0) messages[j] = messages[j].copyWith(pending: false, failed: true);
    }
    _notify();
    onActivity?.call();
  }

  Future<void> retry(Message m) => _send(m.copyWith(pending: true, failed: false));

  Future<void> deleteForEveryone(Message m) async {
    try {
      final now = DateTime.now().toUtc();
      await client
          .from('messages')
          .update({'deleted_at': now.toIso8601String()}).eq('id', m.id);
      final i = messages.indexWhere((x) => x.id == m.id);
      if (i >= 0) messages[i] = messages[i].copyWith(deletedAt: now);
      _notify();
    } catch (_) {}
  }

  // ------------------------------------------------------------- receipts
  /// 0 = sending, 1 = sent, 2 = read (by everyone else in the chat).
  int statusOf(Message m) {
    if (m.pending) return 0;
    final readers = reads[m.id] ?? const <String>{};
    final others = members.keys.where((id) => id != me).toSet();
    if (others.isNotEmpty && others.every(readers.contains)) return 2;
    return 1;
  }

  Message? findById(String? id) {
    if (id == null) return null;
    for (final m in messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    if (_dbChannel != null) client.removeChannel(_dbChannel!);
    if (_liveChannel != null) {
      _liveChannel!.untrack();
      client.removeChannel(_liveChannel!);
    }
    super.dispose();
  }
}
