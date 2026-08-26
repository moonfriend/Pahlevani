import 'package:flutter/widgets.dart';

/// Stub for non-web platforms — `google_sign_in_web` isn't safe to import
/// outside a web compile target, so this file stands in for it there via
/// conditional import (see google_sign_in_render.dart). Never actually
/// called on those platforms: callers branch on kIsWeb first.
Widget googleSignInWebButton() =>
    throw StateError('googleSignInWebButton() should only be called on web');
