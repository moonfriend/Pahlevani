import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// App-wide structured logger.
///
/// In debug builds: pretty-printed output to the console (filtered at trace).
/// In release builds: only warnings and above; errors are forwarded to
/// Firebase Crashlytics as non-fatal events (when Crashlytics is available).
///
/// Usage:
///   AppLogger.d('loading tracks');
///   AppLogger.e('download failed', error: e, stackTrace: st);
class AppLogger {
  AppLogger._();

  static bool _crashlyticsEnabled = false;

  static final Logger _log = Logger(
    printer: kDebugMode
        ? PrettyPrinter(methodCount: 0, colors: true, printEmojis: false)
        : SimplePrinter(printTime: true),
    level: kDebugMode ? Level.trace : Level.warning,
  );

  static void init({required bool crashlyticsEnabled}) {
    _crashlyticsEnabled = crashlyticsEnabled;
  }

  static void d(String message) => _log.d(message);

  static void i(String message) => _log.i(message);

  static void w(String message, {Object? error, StackTrace? stackTrace}) {
    _log.w(message, error: error, stackTrace: stackTrace);
    if (_crashlyticsEnabled && error != null) {
      FirebaseCrashlytics.instance
          .recordError(error, stackTrace, reason: message, fatal: false);
    }
  }

  static void e(
    String message, {
    required Object error,
    StackTrace? stackTrace,
    bool fatal = false,
  }) {
    _log.e(message, error: error, stackTrace: stackTrace);
    if (_crashlyticsEnabled) {
      FirebaseCrashlytics.instance
          .recordError(error, stackTrace, reason: message, fatal: fatal);
    }
  }
}
