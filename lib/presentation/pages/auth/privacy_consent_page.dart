import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/auth/privacy_policy_page.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';

/// Shown once after the first successful sign-in/sign-up (any method,
/// including Google — which has no in-form opportunity for a consent
/// checkbox) and on every app launch until accepted. Blocks access to the
/// rest of the app until the user agrees or signs out.
class PrivacyConsentPage extends StatelessWidget {
  const PrivacyConsentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.traineeSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Before you start training',
                  style: HomeText.gaegu(size: 24)),
              const SizedBox(height: 12),
              Text(
                'We record your training activity — and, if a trainer assigns '
                'you sessions, the training they build for you — only to run '
                'this app for you. Nothing is sold or shared outside that.',
                style:
                    HomeText.patrickHand(size: 15, color: HomeColors.mutedText),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                ),
                child: Text('Read the full notice',
                    style: HomeText.caveat(size: 18, color: HomeColors.teal)),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () => context.read<AuthCubit>().acceptConsent(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HomeColors.orange,
                    borderRadius: HomeRadii.button,
                    border: homeBorder(),
                  ),
                  child: Text('I agree — let me train',
                      style: HomeText.gaegu(size: 17, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: GestureDetector(
                  onTap: () => context.read<AuthCubit>().signOut(),
                  child: Text('Decline & sign out',
                      style: HomeText.patrickHand(
                          size: 14, color: HomeColors.lightMuted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
