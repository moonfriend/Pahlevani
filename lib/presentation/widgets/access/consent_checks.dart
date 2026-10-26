import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../pages/access/consent_texts.dart';

/// Safety and privacy, each a short summary with a link to the full text and
/// a required box, plus an optional box for marketing emails. Shown when
/// creating an account, and again when the terms changed.
class ConsentChecks extends StatelessWidget {
  const ConsentChecks({
    super.key,
    required this.safety,
    required this.privacy,
    required this.marketing,
    required this.onSafetyChanged,
    required this.onPrivacyChanged,
    required this.onMarketingChanged,
  });

  final bool safety;
  final bool privacy;
  final bool marketing;
  final ValueChanged<bool> onSafetyChanged;
  final ValueChanged<bool> onPrivacyChanged;
  final ValueChanged<bool> onMarketingChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
            value: safety,
            onChanged: onSafetyChanged,
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
            value: privacy,
            onChanged: onPrivacyChanged,
          ),
          const SizedBox(height: 16),
          _Box(
            key: const ValueKey('consent-marketing'),
            label: ConsentTexts.marketingCheckbox,
            value: marketing,
            onChanged: onMarketingChanged,
          ),
        ],
      );
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
