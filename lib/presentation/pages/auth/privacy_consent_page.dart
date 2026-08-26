import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/auth/privacy_policy_page.dart';
import 'package:pahlevani/presentation/widgets/common/app_error_dialog.dart';

/// Shown once after a successful sign-in/sign-up, and reachable again via
/// the menu icon until accepted. Not a full-app gate — declining just signs
/// out; the app stays fully usable anonymously either way.
class PrivacyConsentPage extends StatelessWidget {
  const PrivacyConsentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              Navigator.pop(context);
            } else if (state is AuthFailure) {
              showAppErrorDialog(context, message: state.message);
            }
          },
          builder: (context, state) {
            final submitting = state is AuthSubmitting;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Before you start training',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(
                    'We record your training activity — and, if a trainer '
                    'assigns you sessions, the training they build for you — '
                    'only to run this app for you. Nothing is sold or shared '
                    'outside that.',
                    style: TextStyle(color: colors.onMuted, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyPage()),
                    ),
                    child: const Text('Read the full notice'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () => context.read<AuthCubit>().acceptConsent(),
                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('I agree — let me train'),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: submitting
                          ? null
                          : () => context
                              .read<AuthCubit>()
                              .declineConsentAndSignOut(),
                      child: const Text('Decline & sign out'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
