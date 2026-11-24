/// Build-time configuration. Values come from --dart-define only.
/// Never hardcode keys in source.
class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// HTTPS only: a plain http URL is treated as a missing configuration.
  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;
}
