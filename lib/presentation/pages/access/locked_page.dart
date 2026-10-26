import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../bloc/activation/activation_cubit.dart';
import '../../bloc/auth/auth_cubit.dart';
import '../../widgets/access/retry_countdown.dart';
import 'access_scaffold.dart';

/// Signed in, not activated: the admin's message and Patreon link, and a
/// field for the activation code the member got from us.
class LockedPage extends StatefulWidget {
  const LockedPage({super.key, this.email});

  /// The signed-in account, shown so people know which one they're in.
  final String? email;

  @override
  State<LockedPage> createState() => _LockedPageState();
}

class _LockedPageState extends State<LockedPage> {
  final _code = TextEditingController();

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

    return AccessScaffold(
      title: 'Activate Pahlevani',
      children: [
        Text(text.message,
            textAlign: TextAlign.center,
            style: KashiTextStyles.body
                .copyWith(fontSize: 15, height: 1.5, color: colors.textBody)),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => launchUrl(Uri.parse(text.linkUrl),
              mode: LaunchMode.externalApplication),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            shape: const RoundedRectangleBorder(),
          ),
          child: Text(text.linkLabel),
        ),
        const SizedBox(height: 28),
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
        const SizedBox(height: 20),
        if (widget.email != null)
          Text('Signed in as ${widget.email}',
              textAlign: TextAlign.center,
              style: KashiTextStyles.ui
                  .copyWith(fontSize: 12.5, color: colors.textMuted)),
        TextButton(
          onPressed: () {
            context.read<ActivationCubit>().reset();
            context.read<AuthCubit>().signOut();
          },
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
