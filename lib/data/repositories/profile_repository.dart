import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class ProfileRepository {
  ProfileRepository(this.client);
  final SupabaseClient client;

  String get myId => client.auth.currentUser!.id;

  Future<Profile> fetchMe() => fetch(myId);

  Future<Profile> fetch(String id) async {
    final row = await client.from('profiles').select().eq('id', id).single();
    return Profile.fromJson(row);
  }

  Future<List<Profile>> search(String query) async {
    if (query.isEmpty) return [];
    final rows = await client
        .from('profiles')
        .select()
        .ilike('username', '$query%')
        .neq('id', myId)
        .order('username')
        .limit(20);
    return List<Map<String, dynamic>>.from(rows).map(Profile.fromJson).toList();
  }

  /// Throws PostgrestException with code 23505 if the username is taken.
  Future<void> update({
    required String username,
    required String displayName,
    String? about,
    String? avatarPath,
  }) async {
    await client.from('profiles').update({
      'username': username,
      'display_name': displayName,
      'about': (about == null || about.trim().isEmpty) ? null : about.trim(),
      if (avatarPath != null) 'avatar_path': avatarPath,
    }).eq('id', myId);
  }

  Future<void> markProfileSetupDone() async {
    await client.auth.updateUser(UserAttributes(data: {'profile_setup': true}));
  }

  Future<String> uploadAvatar(Uint8List bytes, String ext) async {
    final path = '$myId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
              contentType: ext == 'png' ? 'image/png' : 'image/jpeg'),
        );
    return path;
  }

  String? avatarUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return client.storage.from('avatars').getPublicUrl(path);
  }

  /// Keeps "last seen" fresh.
  Future<void> touchPresence() async {
    try {
      await client.rpc('touch_presence');
    } catch (_) {}
  }
}
