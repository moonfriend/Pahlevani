#!/usr/bin/env bash
# Run the home-redesign entry point against the local Supabase stack.
# Prerequisites: supabase start (run once per machine boot)
# Usage: bash scripts/run_local.sh [extra flutter args]
set -euo pipefail

LOCAL_URL="http://127.0.0.1:54321"
LOCAL_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"

PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig \
flutter run \
  -t lib/main_home_redesign.dart \
  -d linux \
  --dart-define="SUPABASE_URL=${LOCAL_URL}" \
  --dart-define="SUPABASE_ANON_KEY=${LOCAL_ANON_KEY}" \
  "$@"
