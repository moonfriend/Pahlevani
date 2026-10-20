import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_assets.dart';
import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';

/// The frame the gate's screens share: the Rahavi mark, a title, and a
/// narrow centred column that scrolls on short windows.
class AccessScaffold extends StatelessWidget {
  const AccessScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(KashiAssets.rahaviMark,
                      height: 44, semanticLabel: 'Rahavi'),
                  const SizedBox(height: 20),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: KashiTextStyles.title
                          .copyWith(fontSize: 26, color: colors.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(subtitle!,
                        textAlign: TextAlign.center,
                        style: KashiTextStyles.body
                            .copyWith(color: colors.textMuted)),
                  ],
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
