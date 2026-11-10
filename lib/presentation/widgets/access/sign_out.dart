import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/auth/auth_cubit.dart';

/// Title of the note shown after a Steady user signs out.
const steadyStillSignedInTitle = 'Still signed in to Steady';

/// Body of that note.
const steadyStillSignedInBody =
    'You are signed out of Pahlevani Gowd, but your browser may still be '
    'signed in to Steady. To use another Steady account, log out at '
    'steady.page first.';

/// Signs out; afterwards, for an account with Steady linked, explains that
/// Steady itself keeps its own login (apps can't log anyone out of Steady).
///
/// The note goes on the root navigator, which outlives the screen that
/// was tapped: signing out swaps that screen for the account screen.
Future<void> signOutWithSteadyNote(BuildContext context) async {
  final auth = context.read<AuthCubit>();
  final hadSteady = switch (auth.state) {
    AuthAuthenticated(:final user) => user.hasSteady,
    _ => false,
  };
  final navigator = Navigator.of(context, rootNavigator: true);
  await auth.signOut();
  if (!hadSteady || !navigator.mounted) return;
  await showDialog<void>(
    context: navigator.context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(steadyStillSignedInTitle),
      content: const Text(steadyStillSignedInBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
