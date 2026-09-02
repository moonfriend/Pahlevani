import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/auth/privacy_consent_page.dart';
import 'package:pahlevani/presentation/pages/auth/username_login_page.dart';
import 'package:pahlevani/presentation/widgets/auth/google_branded_button.dart';
import 'package:pahlevani/presentation/widgets/auth/google_sign_in_web_button.dart';
import 'package:pahlevani/presentation/widgets/common/app_error_dialog.dart';

/// Google-only sign-in screen. Reached only via the optional login menu
/// entry — anonymous browsing never routes here.
class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Sign in')),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthNeedsConsent) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyConsentPage()),
            );
          } else if (state is AuthAuthenticated) {
            Navigator.pop(context);
          } else if (state is AuthFailure) {
            showAppErrorDialog(context, message: state.message);
          }
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final submitting = state is AuthSubmitting;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Web's Google SDK renders its own branded button and
                    // refuses to be driven imperatively — see
                    // AuthRepository.signInWithGoogle's doc. Native
                    // platforms use Google's pre-approved button image
                    // instead of a hand-built one — see
                    // GoogleBrandedButton's doc.
                    Center(
                      child: kIsWeb
                          ? const GoogleSignInWebButton()
                          : GoogleBrandedButton(
                              onPressed: submitting
                                  ? null
                                  : () => context
                                      .read<AuthCubit>()
                                      .signInWithGoogle(),
                              loading: submitting,
                            ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: submitting
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const UsernameLoginPage()),
                                ),
                        child: const Text('Have a class access code?'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
