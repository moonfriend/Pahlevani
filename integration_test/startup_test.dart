// Regression guard for the MainActivity/audio_service engine-attachment
// crash: every other test in this repo bypasses lib/main.dart and pumps
// PahlevaniApp() directly, so none of them ever call AudioService.init().
// This test calls the REAL app entrypoint instead, the same way the shipped
// app boots, so a broken Activity/FlutterEngine attachment fails here.
//
// Only meaningful on a mobile target — AudioService.init() is a no-op on
// Linux/Web (see main.dart's platform gate).
//
// Run on Android device/emulator:
//   flutter test integration_test/startup_test.dart -d <android-device-id>
//
// NOT included in CI — requires a live Supabase connection and a mobile
// device/emulator. On a fresh install, Android may show a one-time
// POST_NOTIFICATIONS system permission dialog; grant it manually or
// pre-grant with `adb shell pm grant com.pahlevani.app
// android.permission.POST_NOTIFICATIONS` before running unattended.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/data/services/pahlevani_audio_handler.dart';
import 'package:pahlevani/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real main() boots without crashing and attaches the audio_service engine on mobile',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byType(Scaffold), findsWidgets,
          reason: 'App crashed during startup before rendering any UI — '
              'check MainActivity\'s FlutterEngine attachment for audio_service');

      final isMobile =
          !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
      if (isMobile) {
        expect(getIt.isRegistered<PahlevaniAudioHandler>(), isTrue,
            reason: 'AudioService.init() did not attach to the shared '
                'FlutterEngine — MainActivity must extend AudioServiceActivity '
                '(or AudioServiceFragmentActivity)');
      }
    },
  );
}
