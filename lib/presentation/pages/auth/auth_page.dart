import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/auth/privacy_consent_page.dart';

/// Combined sign-in/sign-up screen. Reached only via the optional login
/// menu entry — anonymous browsing never routes here.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSignUp = false;

  bool get _canSubmit =>
      _emailCtrl.text.trim().isNotEmpty && _passwordCtrl.text.isNotEmpty;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    final cubit = context.read<AuthCubit>();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (_isSignUp) {
      cubit.signUpWithEmail(email: email, password: password);
    } else {
      cubit.signInWithEmail(email: email, password: password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: Text(_isSignUp ? 'Create account' : 'Sign in')),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthNeedsConsent) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyConsentPage()),
            );
          } else if (state is AuthAuthenticated) {
            Navigator.pop(context);
          }
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final submitting = state is AuthSubmitting;
            final errorMessage = state is AuthFailure ? state.message : null;
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Email'),
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
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(errorMessage,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: submitting || !_canSubmit ? null : _submit,
                      child: submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_isSignUp ? 'Create account' : 'Sign in'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: submitting
                          ? null
                          : () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(_isSignUp
                          ? 'Already have an account? Sign in'
                          : "Don't have an account? Create one"),
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
