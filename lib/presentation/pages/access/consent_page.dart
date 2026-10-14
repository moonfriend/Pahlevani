import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../bloc/auth/auth_cubit.dart';
import 'access_scaffold.dart';
import 'consent_texts.dart';

/// Safety and privacy, before the app: two required boxes (each with a
/// short summary and a link to the full text) and an optional one for
/// marketing emails. Accepting records the terms version.
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

    return AccessScaffold(
      title: 'Before you start',
      children: [
        const _Summary(
          title: ConsentTexts.safetyTitle,
          points: ConsentTexts.safetyPoints,
          fullTextUrl: ConsentTexts.termsUrl,
          fullTextLabel: 'Read the full terms',
        ),
        _Box(
          key: const ValueKey('consent-safety'),
          label: ConsentTexts.safetyCheckbox,
          value: _safety,
          onChanged: (v) => setState(() => _safety = v),
        ),
        const SizedBox(height: 16),
        const _Summary(
          title: ConsentTexts.privacyTitle,
          points: ConsentTexts.privacyPoints,
          fullTextUrl: ConsentTexts.privacyUrl,
          fullTextLabel: 'Read the privacy policy',
        ),
        _Box(
          key: const ValueKey('consent-privacy'),
          label: ConsentTexts.privacyCheckbox,
          value: _privacy,
          onChanged: (v) => setState(() => _privacy = v),
        ),
        const SizedBox(height: 16),
        _Box(
          key: const ValueKey('consent-marketing'),
          label: ConsentTexts.marketingCheckbox,
          value: _marketing,
          onChanged: (v) => setState(() => _marketing = v),
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

class _Summary extends StatelessWidget {
  const _Summary({
    required this.title,
    required this.points,
    required this.fullTextUrl,
    required this.fullTextLabel,
  });

  final String title;
  final List<String> points;
  final String fullTextUrl;
  final String fullTextLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final body = KashiTextStyles.body
        .copyWith(fontSize: 14, height: 1.5, color: colors.textBody);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: KashiTextStyles.ui.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary)),
        const SizedBox(height: 6),
        for (final point in points) Text('• $point', style: body),
        TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: () => launchUrl(Uri.parse(fullTextUrl),
              mode: LaunchMode.externalApplication),
          child: Text(fullTextLabel),
        ),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(label, style: KashiTextStyles.ui.copyWith(fontSize: 14)),
      );
}
