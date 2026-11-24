import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/chat_summary.dart';
import '../../data/providers.dart';

/// Chat list that reloads whenever Realtime reports a relevant change.
/// RLS means we only receive events for conversations we belong to.
final chatsProvider = StreamProvider.autoDispose<List<ChatSummary>>((ref) {
  final client = ref.watch(supabaseProvider);
  final repo = ref.watch(conversationRepoProvider);
  final ctrl = StreamController<List<ChatSummary>>();
  Timer? debounce;
  var disposed = false;

  Future<void> load() async {
    try {
      final list = await repo.fetchChats();
      if (!disposed) ctrl.add(list);
    } catch (e, s) {
      if (!disposed) ctrl.addError(e, s);
    }
  }

  void scheduleLoad() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), load);
  }

  load();
  final me = client.auth.currentUser?.id ?? 'anon';
  final channel = client
      .channel('chats-list-$me')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: (_) => scheduleLoad(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'participants',
        callback: (_) => scheduleLoad(),
      )
      .subscribe();

  ref.onDispose(() {
    disposed = true;
    debounce?.cancel();
    client.removeChannel(channel);
    ctrl.close();
  });
  return ctrl.stream;
});
