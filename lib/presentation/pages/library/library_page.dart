import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../widgets/kashi/kashi_labels.dart';
import '../../widgets/kashi/khatam.dart';
import '../../layout/kashi_layout.dart';
import 'learning_card_page.dart';
import 'sample_moves.dart';

/// Every move with its video: two to a row on phones, three on tablets,
/// four on the web layout, the thumbnails growing with the tiles. One colour
/// until categories exist. Tap a move → its learning card.
///
/// Shows [sampleMoves] (placeholder) until a moves catalog exists.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, this.moves = sampleMoves});

  final List<SampleMove> moves;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final layout = KashiLayout.of(context);
          final phone = layout.isPhone;
          final columns = layout.bentoColumns;
          final gap = layout.bentoGap;
          final side = switch (layout) {
            KashiLayout.phone => 12.0,
            KashiLayout.tablet => 32.0,
            KashiLayout.web => 40.0,
          };
          final width = math.min(constraints.maxWidth, _maxContentWidth);
          final tileWidth = (width - 2 * side - gap * (columns - 1)) / columns;
          // 108px on the phone's tile; wider tiles get proportionally
          // taller thumbnails (about 200px on the web layout).
          final thumb = phone ? 108.0 : (tileWidth * .74).clamp(108.0, 240.0);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: phone
                        ? const EdgeInsets.fromLTRB(18, 22, 18, 14)
                        : EdgeInsets.fromLTRB(side, 40, side, 24),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text('Library',
                                style: KashiTextStyles.title.copyWith(
                                    fontSize: phone ? null : 34,
                                    color: colors.textPrimary)),
                          ),
                          Text('${moves.length} moves',
                              style: KashiTextStyles.ui.copyWith(
                                  fontSize: phone ? 12 : 14,
                                  color: colors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(side, 0, side, side),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: gap,
                        crossAxisSpacing: gap,
                        mainAxisExtent: thumb + 54,
                      ),
                      itemCount: moves.length,
                      itemBuilder: (context, i) => _MoveTile(
                          move: moves[i],
                          thumbHeight: thumb,
                          // The star window spans the thumbnail's width (the
                          // design's 150px on the phone), so only the
                          // corners show lajvard.
                          starSize: phone ? 150 : tileWidth - 20),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Beyond this the grid stops growing and centres.
  static const _maxContentWidth = 1400.0;
}

class _MoveTile extends StatelessWidget {
  const _MoveTile(
      {required this.move, required this.thumbHeight, required this.starSize});

  final SampleMove move;

  /// 108 on phones, taller on wider tiles.
  final double thumbHeight;
  final double starSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Material(
      color: colors.raised,
      child: InkWell(
        onTap: () => openLibraryLearningCard(context, move),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: thumbHeight,
                child: ClipRect(
                  child: ColoredBox(
                    color: colors.scene500,
                    child: Stack(
                      children: [
                        // A large star window: only the corners show lajvard.
                        Center(
                          child: OverflowBox(
                            maxWidth: starSize,
                            maxHeight: starSize,
                            child: ClipPath(
                              clipper: const KhatamClipper(),
                              child: Image.asset(move.image,
                                  width: starSize,
                                  height: starSize,
                                  fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        if (move.isTracked)
                          const PositionedDirectional(
                              start: 6, top: 6, child: KashiRepsTag()),
                        PositionedDirectional(
                          end: 6,
                          bottom: 6,
                          child: ColoredBox(
                            color: colors.scene700.withValues(alpha: .85),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              child: Text('${move.minutes} min',
                                  style: KashiTextStyles.label.copyWith(
                                      fontSize: 10,
                                      letterSpacing: 0,
                                      color: Colors.white)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(move.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KashiTextStyles.ui.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary)),
                  ),
                  const SizedBox(width: 6),
                  Text(move.nameFa,
                      textDirection: TextDirection.rtl,
                      style: KashiTextStyles.farsi
                          .copyWith(color: colors.farsiAccent)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
