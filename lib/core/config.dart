// Defaults are the prod project — no flags needed for the normal build.
// Local dev against staging: flutter run --dart-define-from-file=.supabase.env
// (copy .supabase.env.example, fill in the staging project's URL + anon key).
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: "https://REDACTED-PROJECT.supabase.co",
);
const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      "REDACTED-SUPABASE-ANON-KEY",
);
