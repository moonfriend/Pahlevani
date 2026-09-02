import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/auth/privacy_consent_page.dart';
import 'package:pahlevani/presentation/widgets/common/app_error_dialog.dart';

/// Admin-managed student login — a trainer-issued username/password/invite
/// code, no email involved. Reached via a link on [AuthPage]; Google stays
/// the primary flow. See AuthRepository.signUpWithInviteCode's doc and
/// supabase/migrations/0016_invite_code_signup.sql.
class UsernameLoginPage extends StatefulWidget {
  const UsernameLoginPage({super.key});

  @override
  State<UsernameLoginPage> createState() => _UsernameLoginPageState();
}

class _UsernameLoginPageState extends State<UsernameLoginPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _inviteCodeCtrl = TextEditingController();
  bool _isSignUp = false;

  bool get _canSubmit =>
      _usernameCtrl.text.trim().isNotEmpty &&
      _passwordCtrl.text.isNotEmpty &&
      (!_isSignUp || _inviteCodeCtrl.text.trim().isNotEmpty);

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _inviteCodeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    final cubit = context.read<AuthCubit>();
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (_isSignUp) {
      cubit.signUpWithInviteCode(
        username: username,
        password: password,
        inviteCode: _inviteCodeCtrl.text.trim(),
      );
    } else {
      cubit.signInWithUsername(username: username, password: password);
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
                    if (_isSignUp) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _inviteCodeCtrl,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Invite code',
                          helperText: 'Given to you by your trainer',
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _submit(),
                      ),
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
                          : "Have an invite code? Create an account"),
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
