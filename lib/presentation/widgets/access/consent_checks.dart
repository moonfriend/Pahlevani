import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../pages/access/consent_texts.dart';
import '../../usage/usage_ui.dart';
import '../../../domain/entities/usage/usage_event.dart';
import '../usage/tap_probe.dart';
import '../usage/tap_probe_ids.dart';

/// Safety and privacy, each a short summary with a link to the full text and
/// a required box. Shown when creating an account, and again when the terms
/// changed. No marketing box: our fans already opted in on Steady.
class ConsentChecks extends StatelessWidget {
  const ConsentChecks({
    super.key,
    required this.safety,
    required this.privacy,
    required this.onSafetyChanged,
    required this.onPrivacyChanged,
    this.onLinkOpened,
  });

  final bool safety;
  final bool privacy;
  final ValueChanged<bool> onSafetyChanged;
  final ValueChanged<bool> onPrivacyChanged;

  /// Told when the full terms or privacy policy is opened.
  final ValueChanged<ExternalLink>? onLinkOpened;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Summary(
            link: ExternalLink.terms,
            onOpened: onLinkOpened,
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
          _Summary(
            link: ExternalLink.privacy,
            onOpened: onLinkOpened,
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
        ],
      );
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.link,
    required this.onOpened,
    required this.title,
    required this.points,
    required this.fullTextUrl,
    required this.fullTextLabel,
  });

  final ExternalLink link;
  final ValueChanged<ExternalLink>? onOpened;
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
        for (final point in points)
          TapProbe(
              id: TapProbeIds.consentText,
              child: Text('• $point', style: body)),
        TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: () {
            onOpened?.call(link);
            openExternalLink(context, link, fullTextUrl);
          },
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
