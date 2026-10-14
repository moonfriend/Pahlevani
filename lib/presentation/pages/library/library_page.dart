import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_assets.dart';
import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../../domain/entities/training_session/exercise.dart';
import '../../../domain/entities/training_session/training_session.dart';
import '../../widgets/exercise_image_provider.dart';
import '../../widgets/kashi/kashi_labels.dart';
import '../home/home_page.dart';
import '../home/session_card.dart';
import '../../widgets/kashi/khatam.dart';
import '../../layout/kashi_layout.dart';
import 'open_move_card.dart';

/// Every session (so ones not on Home, like Advanced Sang and Kabbade, are
/// reachable), then every move in the catalogue: two to a row on phones, three on tablets,
/// four on the web layout, the thumbnails growing with the tiles. One colour
/// until categories exist. Tap a move → its learning card (the same card as
/// the session preview's).
class LibraryPage extends StatelessWidget {
  const LibraryPage({
    super.key,
    required this.moves,
    this.sessions = const [],
    this.onOpenSession,
    this.onSessionMenu,
  });

  /// One exercise per move (see `libraryMoves`).
  final List<Exercise> moves;

  /// Every session the user can see, including those not on Home; listed
  /// Home's first (in their slot order), then the rest by title.
  final List<HomeSession> sessions;
  final ValueChanged<TrainingSession>? onOpenSession;

  /// Long-press: the session's hidden menu (Zoorkhaneh mode).
  final ValueChanged<TrainingSession>? onSessionMenu;

  List<HomeSession> get _orderedSessions => [...sessions]..sort((a, b) {
      final pa = a.session.homePosition, pb = b.session.homePosition;
      if (pa != null || pb != null) {
        if (pa == null) return 1;
        if (pb == null) return -1;
        return pa.compareTo(pb);
      }
      return a.session.title
          .toLowerCase()
          .compareTo(b.session.title.toLowerCase());
    });

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
                  if (sessions.isNotEmpty) ...[
                    _sectionLabel('Sessions', side),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(side, 0, side, side),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: phone ? 1 : columns - 1,
                          mainAxisSpacing: gap,
                          crossAxisSpacing: gap,
                          mainAxisExtent: 72,
                        ),
                        itemCount: _orderedSessions.length,
                        itemBuilder: (context, i) {
                          final s = _orderedSessions[i];
                          return SessionCard(
                            session: s,
                            compact: true,
                            onOpen: () => onOpenSession?.call(s.session),
                            onMenu: onSessionMenu == null
                                ? null
                                : () => onSessionMenu!(s.session),
                          );
                        },
                      ),
                    ),
                    _sectionLabel('Moves', side),
                  ],
                  if (moves.isEmpty)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: side + 6),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                            'No moves yet. They appear once your sessions '
                            'have loaded.',
                            style: KashiTextStyles.body
                                .copyWith(color: colors.textMuted)),
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

  Widget _sectionLabel(String text, double side) => SliverPadding(
        padding: EdgeInsets.fromLTRB(side, 4, side, 10),
        sliver: SliverToBoxAdapter(child: KashiSectionLabel(text)),
      );

  /// Beyond this the grid stops growing and centres.
  static const _maxContentWidth = 1400.0;
}

class _MoveTile extends StatelessWidget {
  const _MoveTile(
      {required this.move, required this.thumbHeight, required this.starSize});

  final Exercise move;

  /// 108 on phones, taller on wider tiles.
  final double thumbHeight;
  final double starSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Material(
      color: colors.raised,
      child: InkWell(
        onTap: () => openMoveCard(context, move),
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
                              child: _Still(move: move, size: starSize),
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
                  if (move.titleFa case final fa? when fa.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(fa,
                        textDirection: TextDirection.rtl,
                        style: KashiTextStyles.farsi
                            .copyWith(color: colors.farsiAccent)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The move's photo or video poster; the pahlevan illustration when it has
/// none or it can't load (offline before the first download).
class _Still extends StatelessWidget {
  const _Still({required this.move, required this.size});

  final Exercise move;
  final double size;

  @override
  Widget build(BuildContext context) {
    final media = move.media;
    final src = switch (media.type) {
      'photo' => media.src,
      'video' => media.poster,
      _ => null,
    };
    final placeholder = Image.asset(KashiAssets.pahlevanFemale,
        width: size, height: size, fit: BoxFit.cover);
    if (src == null || src.isEmpty) return placeholder;
    return Image(
      image: ExerciseImageProvider(src),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}
