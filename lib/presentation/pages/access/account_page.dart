import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../bloc/auth/auth_cubit.dart';
import '../../widgets/kashi/kashi_segmented.dart';
import 'access_scaffold.dart';

/// Sign in, or create an account, with email and password. The email is
/// what we check against our Patreon members; no confirmation mail is sent.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _newAccount = true;

  /// Supabase's minimum.
  static const _minPasswordLength = 6;

  bool get _canSubmit =>
      _email.text.trim().contains('@') &&
      _password.text.length >= (_newAccount ? _minPasswordLength : 1);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    final auth = context.read<AuthCubit>();
    final email = _email.text.trim();
    if (_newAccount) {
      auth.signUpWithEmail(email: email, password: _password.text);
    } else {
      auth.signInWithEmail(email: email, password: _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final state = context.watch<AuthCubit>().state;
    final submitting = state is AuthSubmitting;
    final error = state is AuthFailure ? state.message : null;
    final action = _newAccount ? 'Create account' : 'Sign in';

    return AccessScaffold(
      title: 'Welcome to Pahlevani',
      subtitle: 'For our Patreon members. Use the email you have on Patreon.',
      children: [
        KashiSegmented<bool>(
          options: const [
            (true, 'Create account'),
            (false, 'I have an account')
          ],
          selected: _newAccount,
          onSelected: (value) => setState(() => _newAccount = value),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: [
            _newAccount ? AutofillHints.newPassword : AutofillHints.password
          ],
          decoration: InputDecoration(
            labelText: 'Password',
            helperText: _newAccount ? 'At least 6 characters' : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error,
              style: KashiTextStyles.ui.copyWith(
                  fontSize: 13, color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: submitting || !_canSubmit ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: colors.action,
            minimumSize: const Size.fromHeight(48),
            shape: const RoundedRectangleBorder(),
          ),
          child: submitting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(action),
        ),
      ],
    );
  }
}
