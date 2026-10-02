import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/kashi/kashi_assets.dart';
import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../widgets/kashi/kashi_action_button.dart';
import '../../widgets/kashi/kashi_tile.dart';
import '../../widgets/kashi/khatam.dart';

/// First-open splash: a wall of trained day tiles (what a perfect month looks
/// like), the Rahavi logo in a cream khatam, the promise and Begin.
///
/// Sizes follow the 360×740 phone reference of the design handoff; on short
/// screens the wall gives up height first so nothing overlaps.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key, required this.onBegin});

  final VoidCallback onBegin;

  static const _wallHeight = 420.0;
  static const _wallHeightFraction = .57;
  static const _starSize = 240.0;
  static const _starWidthFraction = .67;

  /// The star's centre sits this far above the wall's bottom edge.
  static const _starCentreAboveWallEdge = 10.0;
  static const _logoToStar = 138 / 240;

  static const _sidePadding = 24.0;
  static const _bottomPadding = 26.0;
  static const _gap = 16.0;
  static const _maxContentWidth = 420.0;

  /// Height kept free below the star for the headline (two lines) + Begin.
  static const _contentBelowStar =
      _gap + 27 * 1.2 * 2 + _gap + KashiActionButton.height + _bottomPadding;

  static const _headline = 'Every session\nlays a tile.';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status-bar icons over the lajvard wall.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.ground,
        body: LayoutBuilder(builder: (context, constraints) {
          final size = constraints.biggest;
          final star = math.min(_starSize, size.width * _starWidthFraction);
          final starOverhang = star / 2 - _starCentreAboveWallEdge;
          final wall = math.min(
            math.min(_wallHeight, size.height * _wallHeightFraction),
            size.height - starOverhang - _contentBelowStar - bottomInset,
          );
          final starTop = wall - _starCentreAboveWallEdge - star / 2;

          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: wall,
                child: const KashiTileWall(),
              ),
              Positioned(
                top: starTop,
                left: (size.width - star) / 2,
                width: star,
                height: star,
                child: ClipPath(
                  clipper: const KhatamClipper(),
                  child: ColoredBox(
                    color: colors.splashStar,
                    child: Center(
                      child: Image.asset(
                        KashiAssets.rahaviLogo,
                        width: star * _logoToStar,
                        semanticLabel: 'Rahavi',
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth + 2 * _sidePadding,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(_sidePadding, 0,
                          _sidePadding, _bottomPadding + bottomInset),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _headline,
                            textAlign: TextAlign.center,
                            style: KashiTextStyles.heading
                                .copyWith(color: colors.textPrimary),
                          ),
                          const SizedBox(height: _gap),
                          KashiActionButton(label: 'Begin', onPressed: onBegin),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
