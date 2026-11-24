import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repositories/conversation_repository.dart';
import 'repositories/media_repository.dart';
import 'repositories/profile_repository.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final profileRepoProvider =
    Provider((ref) => ProfileRepository(ref.watch(supabaseProvider)));
final conversationRepoProvider =
    Provider((ref) => ConversationRepository(ref.watch(supabaseProvider)));
final mediaRepoProvider =
    Provider((ref) => MediaRepository(ref.watch(supabaseProvider)));

/// Current user's profile.
final myProfileProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(profileRepoProvider).fetchMe();
});
