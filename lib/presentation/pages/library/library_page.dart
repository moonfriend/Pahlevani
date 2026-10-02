import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../widgets/kashi/kashi_labels.dart';
import '../../widgets/kashi/khatam.dart';
import 'learning_card_page.dart';
import 'sample_moves.dart';

/// Every move with its video, two to a row. One colour until categories
/// exist. Tap a move → its learning card.
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
          // Phone: 2 columns (the design); wider screens add columns.
          final columns = (constraints.maxWidth / 220).floor().clamp(2, 5);
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 14),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text('Library',
                            style: KashiTextStyles.title
                                .copyWith(color: colors.textPrimary)),
                      ),
                      Text('${moves.length} moves',
                          style: KashiTextStyles.ui
                              .copyWith(fontSize: 12, color: colors.textMuted)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    mainAxisExtent: 162,
                  ),
                  itemCount: moves.length,
                  itemBuilder: (context, i) => _MoveTile(move: moves[i]),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _MoveTile extends StatelessWidget {
  const _MoveTile({required this.move});

  final SampleMove move;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Material(
      color: colors.raised,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LearningCardPage(move: move)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 108,
                child: ClipRect(
                  child: ColoredBox(
                    color: colors.scene500,
                    child: Stack(
                      children: [
                        // A large star window: only the corners show lajvard.
                        Center(
                          child: OverflowBox(
                            maxWidth: 150,
                            maxHeight: 150,
                            child: ClipPath(
                              clipper: const KhatamClipper(),
                              child: Image.asset(move.image,
                                  width: 150, height: 150, fit: BoxFit.cover),
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
