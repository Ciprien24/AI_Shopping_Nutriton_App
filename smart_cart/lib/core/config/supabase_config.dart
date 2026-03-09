class SupabaseConfig {
  static const bool hasUrlDefine = bool.hasEnvironment('SUPABASE_URL');
  static const bool hasAnonKeyDefine = bool.hasEnvironment('SUPABASE_ANON_KEY');

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void validate() {
    // Debug-safe output: existence + length only.
    // ignore: avoid_print
    print(
      '[SupabaseConfig] SUPABASE_URL present: $hasUrlDefine, length: ${url.length}',
    );
    // ignore: avoid_print
    print(
      '[SupabaseConfig] SUPABASE_ANON_KEY present: $hasAnonKeyDefine, length: ${anonKey.length}',
    );

    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'Missing Supabase configuration. Provide SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.',
      );
    }
  }
}
