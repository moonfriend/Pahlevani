import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';

import 'google_sign_in_render.dart';

/// The Google-branded button web requires in place of a plain button + an
/// imperative sign-in call (see AuthRepository.signInWithGoogle's doc).
/// Only ever built when kIsWeb — see AuthPage.
class GoogleSignInWebButton extends StatefulWidget {
  const GoogleSignInWebButton({super.key});

  @override
  State<GoogleSignInWebButton> createState() => _GoogleSignInWebButtonState();
}

class _GoogleSignInWebButtonState extends State<GoogleSignInWebButton> {
  @override
  void initState() {
    super.initState();
    // Kicks off GoogleSignIn.initialize(); the rendered button shows its
    // own "getting ready" placeholder until that resolves.
    unawaited(context.read<AuthCubit>().ensureGoogleSignInReady());
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 44, child: googleSignInWebButton());
  }
}
