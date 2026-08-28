// No hardcoded fallback, on purpose — same pattern as firebase_options.dart
// (see that file's history: commit 3374cef scrubbed real Firebase keys out
// of source for the same reason). Every build, local or CI, must pass real
// values via --dart-define:
//   Local dev: flutter run --dart-define-from-file=.supabase.env
//   (copy .supabase.env.example, fill in the project's real URL/keys)
//   CI/CD: values come from GitHub Actions secrets / Cloudflare Workers
//   Build environment variables, passed as --dart-define flags in the
//   build command — never committed here.
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

// Google OAuth "Web" client ID — counterintuitively, this is the one used by
// the Android app too (passed as serverClientId), not a separate Android
// client ID. Same no-hardcoded-fallback rule as above.
const String googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
