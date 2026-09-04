import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/auth/invite_code_signup_page.dart';
import 'package:pahlevani/presentation/pages/auth/privacy_consent_page.dart';
import 'package:pahlevani/presentation/widgets/auth/google_branded_button.dart';
import 'package:pahlevani/presentation/widgets/auth/google_sign_in_web_button.dart';
import 'package:pahlevani/presentation/widgets/common/app_error_dialog.dart';

/// Sign-in screen: username/password (admin-managed student accounts) and
/// Google, side by side. Reached only via the optional login menu entry —
/// anonymous browsing never routes here. New accounts are created via
/// [InviteCodeSignUpPage], linked at the bottom.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool get _canSubmit =>
      _usernameCtrl.text.trim().isNotEmpty && _passwordCtrl.text.isNotEmpty;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    context.read<AuthCubit>().signInWithUsername(
          username: _usernameCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
  }

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _usernameCtrl,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Username'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: submitting || !_canSubmit ? null : _submit,
                      child: submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: Divider(color: colors.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or',
                              style: TextStyle(color: colors.onMuted)),
                        ),
                        Expanded(child: Divider(color: colors.border)),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                                          const InviteCodeSignUpPage()),
                                ),
                        child: const Text(
                            "Have an invite code? Create an account"),
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
