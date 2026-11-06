import 'package:flutter/material.dart';

import '../../../../core/theme/kashi/kashi_palette.dart';
import '../../../../core/theme/kashi/kashi_typography.dart';
import '../../exercise_image_provider.dart';

/// One row of the [MoveListDrawer].
class MoveListEntry {
  const MoveListEntry({
    required this.name,
    this.nameFa,
    required this.reps,
    this.imageSrc,
    this.isCurrent = false,
    this.isDone = false,
  });

  final String name;
  final String? nameFa;
  final int reps;

  /// The move's photo or video poster; null shows its number only.
  final String? imageSrc;

  final bool isCurrent;

  /// Before the current move in the session.
  final bool isDone;
}

/// Every move of the session, from the player's right edge (swipe left or
/// the edge arrow). Tapping one jumps there; colours follow the top
/// segments: done yellow, current aqua.
class MoveListDrawer extends StatefulWidget {
  const MoveListDrawer(
      {super.key, required this.moves, required this.onSelect});

  final List<MoveListEntry> moves;
  final ValueChanged<int> onSelect;

  /// Fixed row height, so the list can open scrolled to the current move.
  static const double rowHeight = 64;

  @override
  State<MoveListDrawer> createState() => _MoveListDrawerState();
}

class _MoveListDrawerState extends State<MoveListDrawer> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final current = widget.moves.indexWhere((m) => m.isCurrent);
    // One row of the previous move stays in view above the current one.
    _scroll = ScrollController(
        initialScrollOffset:
            current <= 0 ? 0 : (current - 1) * MoveListDrawer.rowHeight);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(int index) {
    Navigator.pop(context); // closes the drawer
    widget.onSelect(index);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: KashiPalette.lajvard900,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('All moves',
                  style: KashiTextStyles.heading
                      .copyWith(fontSize: 20, color: _Scene.text)),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                itemExtent: MoveListDrawer.rowHeight,
                itemCount: widget.moves.length,
                itemBuilder: (_, i) => _MoveRow(
                    number: i + 1,
                    move: widget.moves[i],
                    onTap: () => _select(i)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveRow extends StatelessWidget {
  const _MoveRow(
      {required this.number, required this.move, required this.onTap});

  final int number;
  final MoveListEntry move;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = move.isCurrent
        ? KashiPalette.aqua300
        : move.isDone
            ? KashiPalette.yellow400
            : KashiPalette.lajvard500;
    final nameFa = move.nameFa;
    return Semantics(
      selected: move.isCurrent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: move.isCurrent ? KashiPalette.lajvard700 : null,
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            SizedBox(
              width: 22,
              child: Text('$number',
                  style: KashiTextStyles.ui
                      .copyWith(fontSize: 13, color: _Scene.muted)),
            ),
            _Thumbnail(src: move.imageSrc),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(move.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KashiTextStyles.ui.copyWith(
                          fontSize: 15,
                          fontWeight: move.isCurrent
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: _Scene.text)),
                  if (nameFa != null && nameFa.isNotEmpty)
                    Text(nameFa,
                        maxLines: 1,
                        textDirection: TextDirection.rtl,
                        style: KashiTextStyles.farsi.copyWith(
                            fontSize: 12, color: KashiPalette.yellow400)),
                ],
              ),
            ),
            Text('${move.reps}×',
                style: KashiTextStyles.ui
                    .copyWith(fontSize: 13, color: _Scene.muted)),
          ]),
        ),
      ),
    );
  }
}

/// A 16:9 still of the move, or an empty lajvard box.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.src});

  final String? src;

  @override
  Widget build(BuildContext context) {
    final image = src;
    return SizedBox(
      width: 64,
      height: 36,
      child: ColoredBox(
        color: KashiPalette.lajvard500,
        child: image == null || image.isEmpty
            ? null
            : Image(
                image: ExerciseImageProvider(image),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
      ),
    );
  }
}

/// The player scene's pale tints (same values as the player page's).
abstract final class _Scene {
  static const text = Color(0xFFF4EFE4);
  static const muted = Color(0xFF9AA6D2);
}
