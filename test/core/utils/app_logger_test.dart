import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/utils/app_logger.dart';

void main() {
  group('AppLogger.shouldEnableCrashlytics', () {
    test(
        'is false on web release builds — firebase_crashlytics has no web implementation',
        () {
      expect(
        AppLogger.shouldEnableCrashlytics(isWeb: true, isDebugMode: false),
        isFalse,
      );
    });

    test('is true on non-web release builds', () {
      expect(
        AppLogger.shouldEnableCrashlytics(isWeb: false, isDebugMode: false),
        isTrue,
      );
    });

    test('is false in debug builds regardless of platform', () {
      expect(
        AppLogger.shouldEnableCrashlytics(isWeb: false, isDebugMode: true),
        isFalse,
      );
      expect(
        AppLogger.shouldEnableCrashlytics(isWeb: true, isDebugMode: true),
        isFalse,
      );
    });
  });
}
