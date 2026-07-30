# Testing Flutter Web

`flutter test integration_test/*.dart -d chrome` does not work — Flutter does not support
running the `integration_test` package against a web target this way ("Web devices are not
supported for integration tests yet."). To actually drive the app in a real browser engine, use
`flutter drive` instead, which Flutter does support for web (release/profile mode only; debug
mode is not supported for this path).

## One-time setup

Chromedriver ships bundled inside the Chromium snap, version-matched to the browser — no
separate download needed:

```bash
CHROMEDRIVER=$(find /snap/chromium -maxdepth 4 -name chromedriver | sort -V | tail -1)
"$CHROMEDRIVER" --port=4444 &
```

`test_driver/integration_test.dart` is the standard driver bootstrap (already in the repo) that
`flutter drive` needs as its `--driver` entrypoint.

## Running a test

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  -d web-server --release --browser-name=chrome --web-port=8080
```

Swap `--target` for any other `integration_test/*.dart` file. Each run needs a free
`--web-port`; chromedriver must already be running on port 4444.

## What this catches that `flutter test -d linux` / widget tests can't

`kIsWeb` is a compile-time constant that's always `false` under the normal Dart-VM test runner
— any platform-conditional behavior gated on it (e.g. the download UI being hidden on web, see
`training_sessions_page.dart`) is invisible to `flutter test`. Running via `flutter drive`
against a real web-compiled build with a real browser is the only way in this repo to exercise
that code path. `integration_test/app_test.dart`'s "overflow menu for server session" test is
written to assert differently depending on `kIsWeb` for exactly this reason.

## Known limitation — real-browser media/network bugs (2026-07-30)

The audio-playback bug fixed this session (`audioplayers_web` unconditionally setting
`crossOrigin='anonymous'`, breaking cross-origin media without CORS headers — see
`lib/data/services/just_audio_web_player_service.dart`'s doc comment) was found and confirmed
by a standalone raw-HTML `<audio>` element reproduction in headless Chromium, *not* by an
automated Flutter-level test. An attempt to build an automated regression test for this exact
bug (via `flutter drive`, serving a local fixture on a different port to force a genuine
cross-origin request) did not reliably reproduce the failure when driven through
`AudioPlayersServiceImpl`, despite the raw `<audio>` element reproduction failing consistently
and repeatedly against the identical resource. Two explanations were ruled out (a stray
leftover server holding the test's port; `src`-vs-`crossOrigin` property assignment order) —
the actual cause is still unresolved. Rather than ship a test that doesn't reliably discriminate
between the buggy and fixed backend, no such test exists yet. If picking this up: investigate
via actual browser DevTools (Network/Console tabs) attached to a `flutter drive` run rather than
more isolated reproduction attempts, since this environment has no interactive browser-automation
tool to inspect that directly. See [[project_webapp_first_run]] memory for full history.
