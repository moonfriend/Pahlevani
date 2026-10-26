import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../bloc/auth/auth_cubit.dart';
import '../../widgets/access/consent_checks.dart';
import 'access_scaffold.dart';

/// Signed in, but not agreed to the current terms: after the terms changed
/// (with a notice saying when), or if saving the agreement failed while
/// creating the account. New accounts agree on the sign-in screen instead.
class ConsentPage extends StatefulWidget {
  const ConsentPage({super.key});

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  bool _safety = false;
  bool _privacy = false;
  bool _marketing = false;
  bool _saving = false;

  Future<void> _continue() async {
    setState(() => _saving = true);
    await context.read<AuthCubit>().acceptConsent(marketingOptIn: _marketing);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final state = context.watch<AuthCubit>().state;
    final error = state is AuthFailure ? state.message : null;
    final needs = switch (state) {
      AuthNeedsConsent() => state,
      AuthFailure(previous: final AuthNeedsConsent previous) => previous,
      _ => null,
    };
    final updatedOn = needs?.terms.updatedOn;
    final notice = needs != null && needs.isUpdate
        ? 'Our terms and privacy policy were updated'
            '${updatedOn == null ? '' : ' on ${formatDay(updatedOn)}'}. '
            'Please read them and agree again.'
        : null;

    return AccessScaffold(
      title: 'Before you start',
      children: [
        if (notice != null) ...[
          Text(notice,
              style: KashiTextStyles.body
                  .copyWith(fontSize: 15, height: 1.5, color: colors.textBody)),
          const SizedBox(height: 16),
        ],
        ConsentChecks(
          safety: _safety,
          privacy: _privacy,
          marketing: _marketing,
          onSafetyChanged: (v) => setState(() => _safety = v),
          onPrivacyChanged: (v) => setState(() => _privacy = v),
          onMarketingChanged: (v) => setState(() => _marketing = v),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error,
              style: KashiTextStyles.ui.copyWith(
                  fontSize: 13, color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _safety && _privacy && !_saving ? () => _continue() : null,
          style: FilledButton.styleFrom(
            backgroundColor: colors.action,
            minimumSize: const Size.fromHeight(48),
            shape: const RoundedRectangleBorder(),
          ),
          child: const Text('Continue'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.read<AuthCubit>().declineConsentAndSignOut(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "25 Oct 2026".
String formatDay(DateTime day) =>
    '${day.day} ${_months[day.month - 1]} ${day.year}';
