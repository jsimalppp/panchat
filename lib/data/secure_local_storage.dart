import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores the Supabase session in Android Keystore-backed encrypted storage
/// instead of plain SharedPreferences.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage();

  static const _key = 'panchat_session_v1';
  final FlutterSecureStorage _s = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _s.containsKey(key: _key);

  @override
  Future<String?> accessToken() => _s.read(key: _key);

  @override
  Future<void> removePersistedSession() => _s.delete(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _s.write(key: _key, value: persistSessionString);
}
