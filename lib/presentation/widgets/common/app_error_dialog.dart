import 'package:flutter/material.dart';

/// The one error-surfacing pattern meant to be reused everywhere a Cubit
/// failure needs to reach the user — call this from a `BlocListener` (or
/// anywhere else with a `BuildContext`) instead of building an ad hoc
/// dialog, snackbar, or inline error `Text` per screen. Currently wired
/// into the auth flow only; other screens should adopt the same call
/// rather than inventing their own error UI.
Future<void> showAppErrorDialog(
  BuildContext context, {
  required String message,
  String title = 'Something went wrong',
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
