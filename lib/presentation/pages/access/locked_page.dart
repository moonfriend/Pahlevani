import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../bloc/activation/activation_cubit.dart';
import '../../widgets/access/retry_countdown.dart';
import '../../widgets/access/sign_out.dart';
import 'access_scaffold.dart';
import 'account_page.dart'
    show activateTitle, joinFreeUrl, joinPlansUrl, storeSafeJoinUrl;
import '../../usage/usage_ui.dart';
import '../../../domain/entities/usage/usage_event.dart';
import '../../usage/usage_scope.dart';
import '../../widgets/usage/tap_probe.dart';
import '../../widgets/usage/tap_probe_ids.dart';

/// Signed in, not activated.
///
/// Signed in with Steady (the usual case): who they are, that they haven't
/// joined the Gowd yet, a link to choose a membership (web: every plan;
/// apps: the free plan, store payment rules) and "Check my membership
/// again". A member code is the exception, behind a small link.
///
/// Email accounts: the admin's message and link, the code field, and the
/// re-check.
class LockedPage extends StatefulWidget {
  const LockedPage({
    super.key,
    this.email,
    this.hasSteady = false,
    this.showPlans = kIsWeb,
  });

  /// The signed-in account, shown so people know which one they're in.
  final String? email;

  /// Signed in with Steady: the simple "not joined yet" screen.
  final bool hasSteady;

  /// Link to every plan (web) rather than the free plan (apps).
  final bool showPlans;

  @override
  State<LockedPage> createState() => _LockedPageState();
}

class _LockedPageState extends State<LockedPage> {
  final _code = TextEditingController();
  bool _showCode = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _activate() => context.read<ActivationCubit>().redeem(_code.text);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final state = context.watch<ActivationCubit>().state;
    if (state is! ActivationLocked) return const SizedBox.shrink();
    final text = state.text;
    if (widget.hasSteady) return _notJoined(context, state, colors);

    return AccessScaffold(
      title: activateTitle,
      children: [
        TapProbe(
            id: TapProbeIds.lockedText,
            child: Text(text.message,
                textAlign: TextAlign.center,
                style: KashiTextStyles.body.copyWith(
                    fontSize: 15, height: 1.5, color: colors.textBody))),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {
            context.usage.track(
                const AccessLockedScreenAction(action: LockedAction.link));
            openExternalLink(context, ExternalLink.activationInfo,
                storeSafeJoinUrl(text.linkUrl, showPlans: widget.showPlans));
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            shape: const RoundedRectangleBorder(),
          ),
          child: Text(text.linkLabel),
        ),
        const SizedBox(height: 28),
        ..._codeForm(state, colors),
        const SizedBox(height: 8),
        TextButton(
          onPressed: state.submitting
              ? null
              : () => context.read<ActivationCubit>().recheckMembership(),
          child: const Text(recheckMembershipLabel),
        ),
        const SizedBox(height: 12),
        if (widget.email != null)
          Text('Signed in as ${widget.email}',
              textAlign: TextAlign.center,
              style: KashiTextStyles.ui
                  .copyWith(fontSize: 12.5, color: colors.textMuted)),
        _signOut(context),
      ],
    );
  }

  Widget _notJoined(
      BuildContext context, ActivationLocked state, KashiColors colors) {
    final body = KashiTextStyles.body
        .copyWith(fontSize: 15, height: 1.5, color: colors.textBody);
    return AccessScaffold(
      title: notJoinedTitle,
      children: [
        Text(notJoinedMessage(widget.email ?? 'your Steady account'),
            textAlign: TextAlign.center, style: body),
        const SizedBox(height: 8),
        Text(chooseMembershipHint, textAlign: TextAlign.center, style: body),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            context.usage.track(
                const AccessLockedScreenAction(action: LockedAction.link));
            openExternalLink(context, ExternalLink.activationInfo,
                widget.showPlans ? joinPlansUrl : joinFreeUrl);
          },
          style: FilledButton.styleFrom(
            backgroundColor: colors.action,
            minimumSize: const Size.fromHeight(52),
            shape: const RoundedRectangleBorder(),
          ),
          child: const Text(chooseMembershipLabel),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: state.submitting
              ? null
              : () => context.read<ActivationCubit>().recheckMembership(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: const RoundedRectangleBorder(),
          ),
          child: state.submitting && !_showCode
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text(recheckMembershipLabel),
        ),
        if (state.error != null && !_showCode) ...[
          const SizedBox(height: 12),
          Text(state.error!,
              textAlign: TextAlign.center,
              style: KashiTextStyles.ui.copyWith(
                  fontSize: 13, color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 24),
        if (_showCode)
          ..._codeForm(state, colors)
        else
          TextButton(
            onPressed: () => setState(() => _showCode = true),
            child: Text(haveCodeLabel,
                style: KashiTextStyles.ui
                    .copyWith(fontSize: 13, color: colors.textBody)),
          ),
        const SizedBox(height: 8),
        _signOut(context),
      ],
    );
  }

  List<Widget> _codeForm(ActivationLocked state, KashiColors colors) => [
        TextField(
          controller: _code,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Activation code',
            errorText: state.error,
            errorMaxLines: 3,
          ),
          onSubmitted: (_) => _activate(),
        ),
        const SizedBox(height: 16),
        RetryCountdown(
          until: state.retryAt,
          builder: (context, secondsLeft) => FilledButton(
            onPressed:
                state.submitting || secondsLeft != null ? null : _activate,
            style: FilledButton.styleFrom(
              backgroundColor: colors.action,
              minimumSize: const Size.fromHeight(48),
              shape: const RoundedRectangleBorder(),
            ),
            child: state.submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(secondsLeft != null
                    ? 'Try again in $secondsLeft s'
                    : 'Activate'),
          ),
        ),
      ];

  Widget _signOut(BuildContext context) => TextButton(
        onPressed: () {
          context.usage.track(
              const AccessLockedScreenAction(action: LockedAction.signOut));
          context.read<ActivationCubit>().reset();
          signOutWithSteadyNote(context);
        },
        child: const Text('Sign out'),
      );
}

/// Re-checks the membership (Steady) without signing out.
const recheckMembershipLabel = 'Check my membership again';

/// The "not joined yet" screen (signed in with Steady).
const notJoinedTitle = 'One step left';
String notJoinedMessage(String email) =>
    'You’re signed in with Steady as $email, but you haven’t joined the '
    'Gowd yet.';
const chooseMembershipHint =
    'Choose your membership on our Steady page. The free one is enough to '
    'start. Then come back and check your membership.';
const chooseMembershipLabel = 'Choose your membership';
const haveCodeLabel = 'Have a member code? Enter it here';
