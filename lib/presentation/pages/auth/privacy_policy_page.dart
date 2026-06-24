import 'package:flutter/material.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';

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
          'trainer assigns you individualized training — the sessions they '
          'build for you.',
    ),
    (
      'Why we collect it',
      'Solely to run the app for you: to sign you in, show your training '
          'history and progress, and let a trainer you\'ve connected with '
          'assign you sessions. We do not sell or share your data with '
          'anyone outside of operating this service.',
    ),
    (
      'Who can see it',
      'You, and the trainer you are linked to (only for sessions they '
          'assigned you). Connecting you to a trainer is done by an '
          'administrator after you give the trainer your account email — '
          'we never share your data with a trainer you have not been '
          'linked to.',
    ),
    (
      'Your choices',
      'You can ask us to delete your account and its data at any time. '
          'Declining this notice means you can\'t use the app, since an '
          'account is required to track your training.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.traineeSurface,
      appBar: AppBar(
        backgroundColor: HomeColors.traineeSurface,
        elevation: 0,
        title: Text('Privacy & Data Use', style: HomeText.gaegu(size: 20)),
        iconTheme: const IconThemeData(color: HomeColors.ink),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: HomeColors.amberTint,
              borderRadius: HomeRadii.tile,
              border: homeBorder(),
            ),
            child: Text(
              'Draft notice — this is a starting point written for honesty '
              'about what the app does, not a substitute for legal review.',
              style: HomeText.patrickHand(
                  size: 13, color: HomeColors.orangeTextDeep),
            ),
          ),
          for (final (title, body) in _sections) ...[
            Text(title, style: HomeText.gaegu(size: 18)),
            const SizedBox(height: 6),
            Text(body,
                style: HomeText.patrickHand(
                    size: 14.5, color: HomeColors.mutedText)),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}
