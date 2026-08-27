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

// Google OAuth "Web" client ID — counterintuitively, this is the one used by
// the Android app too (passed as serverClientId), not a separate Android
// client ID. Hardcoded default for the same reason as the Supabase values
// above: not a secret (OAuth client IDs are meant to be public — see
// CLAUDE.md's exemption note), and CI/deploy pipelines (e.g. the Cloudflare
// Workers Build for release/staging) don't pass --dart-define flags, so an
// empty default here silently breaks Google sign-in there ("Missing
// required parameter: client_id") rather than failing the build loudly.
const String googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: 'REDACTED-GOOGLE-CLIENT-ID',
);
