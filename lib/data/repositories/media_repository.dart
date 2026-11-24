import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class MediaRepository {
  MediaRepository(this.client);
  final SupabaseClient client;

  static const bucket = 'chat-media';

  /// Uploads to chat-media/<conv>/<user>/<uuid>.<ext> and returns the path.
  Future<String> upload({
    required String conversationId,
    required String fileId,
    required Uint8List bytes,
    required String ext,
    required String contentType,
  }) async {
    final me = client.auth.currentUser!.id;
    final path = '$conversationId/$me/$fileId.$ext';
    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return path;
  }

  Future<String> signedUrl(String path) =>
      client.storage.from(bucket).createSignedUrl(path, 60);
}
