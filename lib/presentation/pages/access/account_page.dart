import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../../domain/entities/activation/locked_screen_text.dart';
import '../../bloc/activation/activation_cubit.dart';
import '../../bloc/auth/auth_cubit.dart';
import '../../widgets/access/consent_checks.dart';
import '../../widgets/access/retry_countdown.dart';
import '../../widgets/kashi/kashi_segmented.dart';
import 'access_scaffold.dart';

/// The one screen after onboarding. "Create account" takes the email,
/// password, activation code and the safety/privacy agreement together;
/// "I have an account" takes just the email and password. No confirmation
/// mail is sent.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _newAccount = true;
  bool _safety = false;
  bool _privacy = false;
  bool _marketing = false;
  late final Future<LockedScreenText> _codeSource =
      context.read<ActivationCubit>().lockedScreenText();

  /// Supabase's minimum.
  static const _minPasswordLength = 6;

  bool get _canSubmit {
    final emailAndPassword = _email.text.trim().contains('@') &&
        _password.text.length >= (_newAccount ? _minPasswordLength : 1);
    if (!_newAccount) return emailAndPassword;
    return emailAndPassword &&
        _code.text.trim().isNotEmpty &&
        _safety &&
        _privacy;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    final auth = context.read<AuthCubit>();
    final email = _email.text.trim();
    if (_newAccount) {
      auth.registerWithCode(
        email: email,
        password: _password.text,
        code: _code.text,
        marketingOptIn: _marketing,
      );
    } else {
      auth.signInWithEmail(email: email, password: _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final state = context.watch<AuthCubit>().state;
    final submitting = state is AuthSubmitting;
    final failure = state is AuthFailure ? state : null;
    final codeError =
        failure?.field == AuthFailureField.code ? failure!.message : null;
    final generalError =
        failure?.field == AuthFailureField.general ? failure!.message : null;
    final action = _newAccount ? 'Create account' : 'Sign in';

    return AccessScaffold(
      title: 'Welcome to Pahlevani',
      subtitle: _newAccount
          ? 'Create your account with the activation code you got from us.'
          : 'Sign in with your email and password.',
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
        if (_newAccount) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Activation code',
              errorText: codeError,
              errorMaxLines: 3,
            ),
            onChanged: (_) => setState(() {}),
          ),
          _CodeSourceLink(source: _codeSource),
          const SizedBox(height: 8),
          ConsentChecks(
            safety: _safety,
            privacy: _privacy,
            marketing: _marketing,
            onSafetyChanged: (v) => setState(() => _safety = v),
            onPrivacyChanged: (v) => setState(() => _privacy = v),
            onMarketingChanged: (v) => setState(() => _marketing = v),
          ),
        ],
        if (generalError != null) ...[
          const SizedBox(height: 12),
          Text(generalError,
              style: KashiTextStyles.ui.copyWith(
                  fontSize: 13, color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        RetryCountdown(
          until: failure?.retryAt,
          builder: (context, secondsLeft) => FilledButton(
            onPressed: submitting || secondsLeft != null || !_canSubmit
                ? null
                : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: colors.action,
              minimumSize: const Size.fromHeight(48),
              shape: const RoundedRectangleBorder(),
            ),
            child: submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(secondsLeft != null
                    ? 'Try again in $secondsLeft s'
                    : action),
          ),
        ),
      ],
    );
  }
}

/// Where to get a code: the locked screen's admin-set link.
class _CodeSourceLink extends StatelessWidget {
  const _CodeSourceLink({required this.source});

  final Future<LockedScreenText> source;

  @override
  Widget build(BuildContext context) => FutureBuilder<LockedScreenText>(
        future: source,
        builder: (context, snapshot) {
          final text = snapshot.data;
          if (text == null) return const SizedBox.shrink();
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => launchUrl(Uri.parse(text.linkUrl),
                  mode: LaunchMode.externalApplication),
              child: Text(text.linkLabel),
            ),
          );
        },
      );
}
