# Pahlevani Release Checklist

## 1 — Prepare the branch

- [ ] All tests green: `flutter test`
- [ ] Coverage ≥ 65%: `flutter test --coverage` → check CI output
- [ ] `flutter analyze` — zero errors, zero warnings
- [ ] `dart format --set-exit-if-changed .` — no formatting diff

## 2 — Version bump

Edit `pubspec.yaml`:
```
version: X.Y.Z+B
```
Where `B` is incremented by 1 each release (Google Play requires monotonically increasing build number).

## 3 — Run CI

Push to a PR targeting `main`. All three CI jobs must be green:
- **Format, Analyze, Test** — lint + unit/widget tests + coverage gate
- **Build APKs** — debug + release APK compile (catches R8/ProGuard issues)
- **Integration Tests (Linux)** — fake-repo journeys on Linux desktop

## 4 — Build the signed release bundle

Requires `android/key.properties` (gitignored — keep on your machine only):
```
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<path-to-keystore.jks>
```

```bash
flutter build appbundle --release \
  --dart-define=FIREBASE_ANDROID_API_KEY=<value> \
  --dart-define=FIREBASE_IOS_API_KEY=<value> \
  --dart-define=FIREBASE_WEB_API_KEY=<value>
```

Output: `build/app/outputs/bundle/release/app-release.aab`

## 5 — Supabase migration (if schema changed)

Run any new migration in the Supabase SQL Editor in the correct order:
- `supabase/migrations/0001_initial_schema.sql` — baseline (idempotent)
- `supabase/migrations/0002_app_release_gate.sql` — version gate table
- Add future migrations here in order

Verify with the migration test suite locally first:
```bash
bash scripts/test_migration.sh
```

## 6 — Google Play upload

1. Open Play Console → Pahlevani app → Internal testing track (or Production)
2. Create new release → upload `app-release.aab`
3. Add release notes (what changed for users)
4. Review → Submit

## 7 — Post-release

- [ ] Merge the release branch to `main`
- [ ] Tag the commit: `git tag v{X.Y.Z}` and push the tag
- [ ] Update `MEMORY.md` "Current State" with new version
- [ ] If the release-gate table exists in Supabase, optionally update `min_build` via admin.py → Release Gate tab

---

## Fastlane (future)

Fastlane is a CI/CD tool that can automate steps 4–6. When ready:

**What it does:**
- `fastlane supply` — uploads AAB directly to Play Console via Google Play API
- `fastlane screengrab` — takes screenshots on emulators for Play Store listing
- `fastlane match` — manages iOS signing certificates (not needed for Android only)

**Setup cost:** ~2–4 hours:
1. Install: `gem install fastlane`
2. `fastlane init` in project root → choose "Android + Google Play"
3. Create a Google Play service account (JSON key) with "Release manager" role
4. Store the JSON key in a GitHub Actions secret
5. Write a `Fastfile` with a `beta` and `production` lane

**Recommendation:** Do this after iOS support is live — that's when multi-platform release automation really earns its keep. Until then, the manual checklist is fast enough.

---

## Signing keys

`android/key.properties` and `*.jks` are gitignored — keep your keystore backed up
externally (e.g., encrypted cloud storage). If lost, a new upload key must be registered
with Google Play — process takes ~1 week.
