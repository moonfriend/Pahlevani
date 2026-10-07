import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_assets.dart';
import '../../../core/theme/kashi/kashi_palette.dart';

/// What a move shows when it has neither a video nor a photo yet: the
/// pahlevan illustration on lajvard, never an empty box.
class MovePlaceholder extends StatelessWidget {
  const MovePlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: KashiPalette.lajvard500,
        child: Padding(
          padding: EdgeInsets.only(top: 8),
          child: Image(
            image: AssetImage(KashiAssets.pahlevanMale),
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
          ),
        ),
      );
}
