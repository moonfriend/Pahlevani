import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_links.dart';
import '../../../core/theme/kashi/kashi_assets.dart';

/// The Rahavi mark. Tapping it opens a menu: who we are, and the legal
/// pages (privacy notice, Impressum, terms).
///
/// Why on the mark: German law wants the Impressum and the privacy notice
/// reachable at any time, not only at sign-up. Every screen that shows the
/// mark (home header, web side rail, sign-in and locked screens) uses this
/// button, so the links are one tap away everywhere.
class RahaviMenuButton extends StatelessWidget {
  const RahaviMenuButton({
    super.key,
    this.width,
    this.height,
    this.openLink = _openInBrowser,
  });

  final double? width;
  final double? height;

  /// Opens a page; tests pass a fake.
  final Future<void> Function(Uri uri) openLink;

  static const entries = [
    ('Who is Rahavi', AppLinks.rahavi),
    ('Privacy notice', AppLinks.privacy),
    ('Impressum', AppLinks.impressum),
    ('Terms of use', AppLinks.terms),
  ];

  static Future<void> _openInBrowser(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Rahavi: about us and legal',
      padding: EdgeInsets.zero,
      onSelected: (url) => openLink(Uri.parse(url)),
      itemBuilder: (_) => [
        for (final (label, url) in entries)
          PopupMenuItem(value: url, child: Text(label)),
      ],
      child: Image.asset(KashiAssets.rahaviMark,
          width: width, height: height, semanticLabel: 'Rahavi'),
    );
  }
}
