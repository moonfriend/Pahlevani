import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pahlevani/core/theme/pahlevani_colors.dart';

/// Full-screen, unskippable — shown when the version gate decides this
/// install must update before continuing. No back button, no dismiss.
class VersionGateScreen extends StatelessWidget {
  const VersionGateScreen({super.key, required this.message});

  final String message;

  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.pahlevani.app';

  Future<void> _openPlayStore() async {
    final uri = Uri.parse(_playStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>();
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors?.bg ?? cs.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.system_update_rounded, size: 56, color: cs.primary),
                const SizedBox(height: 20),
                Text(
                  'Update required',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: cs.onSurface, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colors?.onMuted ?? cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _openPlayStore,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text('Update now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
