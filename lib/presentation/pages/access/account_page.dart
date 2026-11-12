import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../../usage/usage_ui.dart';
import '../../../domain/entities/usage/usage_event.dart';
import '../../usage/usage_scope.dart';

/// The one screen after onboarding, in two tabs:
///  - "Already a member": "Sign in with Steady" (terms are asked on the
///    next screen);
///  - "Join the Gowd": how to become a member, a link to Steady, and the
///    same sign-in button for when they come back. Store payment rules:
///    only the web links to the paid plans; the apps link to the free
///    sign-up ([showJoinLink]).
/// Under the member tab, "Other ways to sign in" opens the older email forms, kept
/// for gifted codes, the store reviewer and existing email accounts:
/// "Create account" takes the email, password, activation code and the
/// safety/privacy agreement together; "I have an account" takes just the
/// email and password. No confirmation mail is sent.
class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    this.showJoinLink = kIsWeb,
    this.openUrl = _openExternally,
  });

  /// Link to the paid plans (web only); otherwise to the free sign-up.
  final bool showJoinLink;

  /// Opens a Steady page outside the app (replaced in tests).
  final Future<void> Function(String url) openUrl;

  static Future<void> _openExternally(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _memberTab = true;
  bool _showOtherWays = false;

  /// The join page was opened: coming back to the app starts sign-in
  /// (once), so a new member doesn't have to find the button.
  bool _awaitingJoin = false;
  bool _welcomeBack = false;
  late final AppLifecycleListener _lifecycle =
      AppLifecycleListener(onResume: _onResume);
  bool _newAccount = true;
  bool _safety = false;
  bool _privacy = false;
  late final Future<LockedScreenText> _codeSource =
      context.read<ActivationCubit>().lockedScreenText();

  /// Supabase's minimum.
  static const _minPasswordLength = 6;

  // For the usage study: time on screen, corrections, attempts — never
  // what was typed.
  final DateTime _openedAt = DateTime.now();
  final Map<String, int> _lengths = {};
  int _corrections = 0;
  int _attempts = 0;

  /// A field changed: counts it as a correction when it got shorter.
  void _edited(String field, String text) {
    if (text.length < (_lengths[field] ?? 0)) _corrections++;
    _lengths[field] = text.length;
    setState(() {});
  }

  void _setMode(bool newAccount) {
    if (newAccount == _newAccount) return;
    context.usage.track(AuthScreenMode(
        mode: newAccount ? AuthMode.createAccount : AuthMode.signIn));
    setState(() => _newAccount = newAccount);
  }

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
  void initState() {
    super.initState();
    _lifecycle; // start listening
  }

  Future<void> _openJoinPage(String url) async {
    _awaitingJoin = true;
    await widget.openUrl(url);
  }

  void _onResume() {
    if (!_awaitingJoin || !mounted) return;
    _awaitingJoin = false;
    setState(() => _welcomeBack = true);
    context.read<AuthCubit>().signInWithSteady();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    context.usage.track(AuthSubmit(
      mode: _newAccount ? AuthMode.createAccount : AuthMode.signIn,
      secondsOnScreen:
          DateTime.now().difference(_openedAt).inMilliseconds / 1000,
      corrections: _corrections,
      attempt: ++_attempts,
    ));
    _corrections = 0;
    final auth = context.read<AuthCubit>();
    final email = _email.text.trim();
    if (_newAccount) {
      auth.registerWithCode(
        email: email,
        password: _password.text,
        code: _code.text,
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

    final errorText = generalError == null
        ? null
        : Text(generalError,
            style: KashiTextStyles.ui.copyWith(
                fontSize: 13, color: Theme.of(context).colorScheme.error));

    final steadyButton = FilledButton(
      onPressed: submitting
          ? null
          : () => context.read<AuthCubit>().signInWithSteady(),
      style: FilledButton.styleFrom(
        backgroundColor: colors.action,
        minimumSize: const Size.fromHeight(52),
        shape: const RoundedRectangleBorder(),
      ),
      child: const Text(steadySignInLabel),
    );
    final tabs = KashiSegmented<bool>(
      options: const [(true, memberTabLabel), (false, joinTabLabel)],
      selected: _memberTab,
      onSelected: (value) => setState(() => _memberTab = value),
    );

    if (!_memberTab) {
      return AccessScaffold(
        title: 'Welcome to Pahlevani Gowd',
        children: [
          tabs,
          const SizedBox(height: 20),
          _JoinTab(showPlans: widget.showJoinLink, onOpen: _openJoinPage),
          if (_welcomeBack) ...[
            const SizedBox(height: 16),
            Text(welcomeBackMessage,
                style: KashiTextStyles.ui.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary)),
          ],
          const SizedBox(height: 24),
          Text('Joined already?',
              style: KashiTextStyles.ui
                  .copyWith(fontSize: 13, color: colors.textBody)),
          const SizedBox(height: 8),
          steadyButton,
          if (errorText != null) ...[
            const SizedBox(height: 12),
            errorText,
          ],
        ],
      );
    }

    return AccessScaffold(
      title: 'Welcome to Pahlevani Gowd',
      children: [
        tabs,
        const SizedBox(height: 20),
        steadyButton,
        if (!_showOtherWays && errorText != null) ...[
          const SizedBox(height: 12),
          errorText,
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _showOtherWays = !_showOtherWays),
          child: Text(otherWaysLabel,
              style: KashiTextStyles.ui
                  .copyWith(fontSize: 13, color: colors.textBody)),
        ),
        if (_showOtherWays) ...[
          const SizedBox(height: 12),
          KashiSegmented<bool>(
            options: const [
              (true, 'Create account'),
              (false, 'I have an account')
            ],
            selected: _newAccount,
            onSelected: _setMode,
          ),
          const SizedBox(height: 20),
          if (_newAccount) ...[
            _ActivateIntro(source: _codeSource, showPlans: widget.showJoinLink),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
            onChanged: (v) => _edited('email', v),
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
            onChanged: (v) => _edited('password', v),
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
              onChanged: (v) => _edited('code', v),
            ),
            const SizedBox(height: 16),
            ConsentChecks(
              safety: _safety,
              privacy: _privacy,
              onSafetyChanged: (v) => setState(() => _safety = v),
              onPrivacyChanged: (v) => setState(() => _privacy = v),
            ),
          ],
          if (errorText != null) ...[
            const SizedBox(height: 12),
            errorText,
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
      ],
    );
  }
}

/// The "Join the Gowd" tab: what membership is and where to get it.
class _JoinTab extends StatelessWidget {
  const _JoinTab({required this.showPlans, required this.onOpen});

  final bool showPlans;
  final void Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final (label, url) = showPlans
        ? (joinPlansLabel, joinPlansUrl)
        : (joinFreeLabel, joinFreeUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(joinIntro,
            style: KashiTextStyles.body
                .copyWith(fontSize: 14, height: 1.5, color: colors.textBody)),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => onOpen(url),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: const RoundedRectangleBorder(),
          ),
          child: Text(label),
        ),
      ],
    );
  }
}

/// "Activate and enter the Gowd": the admin-set text on how to get a code
/// (Steady today) and its link. Only on the create tab.
class _ActivateIntro extends StatelessWidget {
  const _ActivateIntro({required this.source, required this.showPlans});

  final Future<LockedScreenText> source;
  final bool showPlans;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return FutureBuilder<LockedScreenText>(
      future: source,
      builder: (context, snapshot) {
        final text = snapshot.data ?? LockedScreenText.fallback;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(activateTitle,
                style: KashiTextStyles.ui.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary)),
            const SizedBox(height: 6),
            Text(text.message,
                style: KashiTextStyles.body.copyWith(
                    fontSize: 14, height: 1.5, color: colors.textBody)),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => openExternalLink(
                  context,
                  ExternalLink.activationInfo,
                  storeSafeJoinUrl(text.linkUrl, showPlans: showPlans)),
              child: Text(text.linkLabel),
            ),
          ],
        );
      },
    );
  }
}

/// The heading over how to get an activation code (here and on the locked
/// screen).
const activateTitle = 'Activate and enter the Gowd';

/// The main button on the account screen.
const steadySignInLabel = 'Sign in with Steady';

/// Opens the email + code forms under the Steady button.
const otherWaysLabel = 'Other ways to sign in';

/// The two tabs of the account screen.
const memberTabLabel = 'Already a member';
const joinTabLabel = 'Join the Gowd';

/// What the join tab says.
const joinIntro = 'Pahlevani Gowd is for members of our Steady page. '
    'Join for free or pick a plan that supports our work. When you come '
    'back here, we finish signing you in.';

/// Shown when the app starts sign-in after the join page.
const welcomeBackMessage = 'Welcome back! Finishing your sign-in…';

/// Web: every plan, paid ones included.
const joinPlansLabel = 'See the plans';
const joinPlansUrl = 'https://steady.page/join-the-gowd';

/// Apps (store payment rules): the free sign-up only.
const joinFreeLabel = 'Join for free';

/// "The Open Gowd" (€0), checked against Steady's plan list 2026-11-08.
const joinFreeUrl =
    'https://steady.page/en/plans/2e5a61f7-0a6f-4a8f-b026-7426d73054b5';

/// The admin's join link (locked-screen text) may point at paid plans. The
/// apps must not link to outside payments (store rules), so there it always
/// opens the free plan; web keeps the admin's link.
String storeSafeJoinUrl(String adminUrl, {required bool showPlans}) =>
    showPlans ? adminUrl : joinFreeUrl;
