import 'package:flutter/material.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';

/// Draft data-use notice — NOT legally reviewed. Placeholder copy written to
/// be honest about what the app actually does (record training data to run
/// the service, nothing else) so there is something concrete to replace
/// with real legal text before this ships to users.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const _sections = <(String, String)>[
    (
      'What we collect',
      'Your email address, the training sessions you complete, and — if a '
          "trainer assigns you individualized training — the sessions they "
          'build for you.',
    ),
    (
      'Why we collect it',
      'Solely to run the app for you: to sign you in, show your training '
          'history and progress, and let a trainer you\'re connected with '
          'assign you sessions. We do not sell or share your data with '
          'anyone outside of operating this service.',
    ),
    (
      'Who can see it',
      "You, and your trainer — but only for sessions they assigned you. "
          "Connecting you to a trainer is done by an administrator, never "
          "automatically.",
    ),
    (
      'Your choices',
      'You can ask to have your account and its data deleted at any time. '
          'Declining this notice signs you out — you can keep using the app '
          'anonymously without an account, you just won\'t have activity '
          'tracking or assigned sessions.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Privacy & Data Use')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Draft notice — a starting point written for honesty about '
              'what the app does, not a substitute for legal review.',
              style: TextStyle(color: colors.onMuted, fontSize: 13),
            ),
          ),
          for (final (title, body) in _sections) ...[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body, style: TextStyle(color: colors.onMuted, height: 1.4)),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}
