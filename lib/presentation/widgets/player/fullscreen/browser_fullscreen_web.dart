import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../../../core/utils/app_logger.dart';

/// Asks the browser for real full screen. Browsers allow it only right after
/// a tap, and iPhone Safari not at all; then the video still fills the page.
void enterBrowserFullscreen() {
  final root = web.document.documentElement;
  if (root == null || web.document.fullscreenElement != null) return;
  root.requestFullscreen().toDart.catchError((Object e) {
    AppLogger.d('Browser full screen refused: $e');
    return null;
  });
}

void exitBrowserFullscreen() {
  if (web.document.fullscreenElement == null) return;
  web.document.exitFullscreen().toDart.catchError((Object e) {
    AppLogger.d('Leaving browser full screen failed: $e');
    return null;
  });
}
