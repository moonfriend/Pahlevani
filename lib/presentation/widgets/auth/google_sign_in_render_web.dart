import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Renders Google's own "Sign in with Google" button (Google Identity
/// Services). Web has no imperative sign-in call — see
/// AuthRepository.signInWithGoogle's doc — so this replaces the plain
/// button used on other platforms.
Widget googleSignInWebButton() => web.renderButton();
