class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'MEDSENTRY_SUPABASE_URL',
    defaultValue: 'https://hcvqmlifeuovxavthmcu.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'MEDSENTRY_SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable__nSG0nDpvg_C3VqlkPDcZg_gOGLI4n-',
  );
}
