import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../../domain/entities/training_session/exercise.dart';
import '../../layout/kashi_layout.dart';
import '../../widgets/exercise_image_provider.dart';
import '../../widgets/kashi/kashi_action_button.dart';
import '../../widgets/kashi/kashi_labels.dart';
import '../../widgets/kashi/kashi_variation_selector.dart';
import '../../widgets/kashi/move_placeholder.dart';
import '../../widgets/player/exercise_demo_video_player.dart';
import '../../widgets/player/learnt_toggle.dart';
import 'sample_moves.dart';

/// What the learning card shows about one move — from the Library's sample
/// moves or from a session's real move.
class LearningMove {
  const LearningMove({
    this.exerciseId,
    required this.name,
    this.nameFa,
    this.minutes,
    this.target,
    this.description,
    this.steps = const [],
    this.cues = const [],
    this.variations = const [],
    this.photo,
    this.videoSrc,
  });

  /// A Library sample move (placeholder catalogue, no video).
  factory LearningMove.fromSample(SampleMove move) => LearningMove(
        name: move.name,
        nameFa: move.nameFa,
        minutes: move.minutes,
        target: move.target,
        description: move.description,
        steps: move.steps,
        variations: move.variations,
        photo: AssetImage(move.image),
      );

  /// A session's move. [media] and [videoReady] are the already-resolved
  /// media (local file where downloaded): the video plays only when
  /// [videoReady], otherwise the poster or photo shows. [target] is set for
  /// a counted move.
  factory LearningMove.fromExercise(
    Exercise exercise, {
    required ExerciseMedia media,
    required bool videoReady,
    int? target,
    int? minutes,
  }) {
    final src = media.src ?? '';
    final still = switch (media.type) {
      'photo' => media.src,
      'video' => media.poster,
      _ => null,
    };
    return LearningMove(
      exerciseId: exercise.id,
      name: exercise.name,
      nameFa: exercise.titleFa,
      minutes: minutes,
      target: target,
      description: exercise.description,
      steps: exercise.steps,
      cues: exercise.cues,
      variations: exercise.variations,
      photo: (still == null || still.isEmpty)
          ? null
          : ExerciseImageProvider(still),
      videoSrc:
          (videoReady && media.type == 'video' && src.isNotEmpty) ? src : null,
    );
  }

  /// The session exercise this card is for; null for placeholder Library
  /// samples. When set, the card offers the "Learnt" switch.
  final int? exerciseId;
  final String name;
  final String? nameFa;
  final int? minutes;

  /// Reps when a trainer flagged this move for counting.
  final int? target;
  final String? description;
  final List<String> steps;

  /// "Pay attention to" points.
  final List<String> cues;

  /// Lightest first; the middle one is the standard move.
  final List<MoveVariation> variations;

  /// The still; null shows the pahlevan illustration.
  final ImageProvider? photo;

  /// A playable video (local file, or URL on web); null hides the play
  /// button.
  final String? videoSrc;
}

/// Opens [move]'s learning card over a session or the player: a full page
/// on phones, a centred two-column card over the dimmed page on tablets and
/// in the web layout. Resolves to true when the action was pressed, false when
/// the card was closed (Back, ✕ or a tap beside it) — so a caller acts only
/// once the card has fully closed. The video starts straight away, as the
/// design asks when the card is opened from a session.
Future<bool> showLearningCard(
  BuildContext context,
  LearningMove move, {
  String actionLabel = 'Got it',
}) async {
  final result = await _pushLearningCard(
    context,
    LearningCardPage(
      move: move,
      actionLabel: actionLabel,
      autoplayVideo: true,
    ),
  );
  return result ?? false;
}

/// Opens a Library sample move's learning card, the same way.
Future<void> openLibraryLearningCard(BuildContext context, SampleMove move) =>
    _pushLearningCard(context, LearningCardPage.sample(move));

Future<bool?> _pushLearningCard(BuildContext context, LearningCardPage page) {
  if (KashiLayout.of(context).isPhone) {
    return Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => page));
  }
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: page.move.name,
    barrierColor: const Color(0x9E060C1E), // rgba(6,12,30,.62)
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => page,
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Learn a single move: the photo (ending in the lower half of a khatam) or
/// its video, the name with its reps, Lighter/Harder variations, the
/// description, numbered steps and the points to pay attention to, then one
/// action. The one learning card of the app — the Library, the session
/// preview and Learning mode all use it.
class LearningCardPage extends StatefulWidget {
  const LearningCardPage({
    super.key,
    required this.move,
    this.actionLabel = 'Got it',
    this.onAction,
    this.autoplayVideo = false,
  });

  /// The Library's card: "Let’s go" (practising one move) isn't built yet.
  factory LearningCardPage.sample(SampleMove move, {Key? key}) =>
      LearningCardPage(
        key: key,
        move: LearningMove.fromSample(move),
        actionLabel: 'Let’s go',
        onAction: (context) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text(
                  'Practising a single move arrives with the new player.'))),
      );

  final LearningMove move;
  final String actionLabel;

  /// Defaults to closing the card with `true`.
  final void Function(BuildContext context)? onAction;

  /// Opens with the video playing instead of the photo.
  final bool autoplayVideo;

  @override
  State<LearningCardPage> createState() => _LearningCardPageState();
}

class _LearningCardPageState extends State<LearningCardPage> {
  /// The standard variation sits in the middle of the list.
  late int _variation = widget.move.variations.length ~/ 2;

  late bool _videoOpen = widget.autoplayVideo && widget.move.videoSrc != null;

  static const _photoHeight = 262.0;
  static const _maxWidth = 480.0;

  LearningMove get _move => widget.move;
  bool get _hasVariations => _move.variations.isNotEmpty;
  MoveVariation? get _selected =>
      _hasVariations ? _move.variations[_variation] : null;

  void _act() {
    final onAction = widget.onAction;
    if (onAction != null) {
      onAction(context);
    } else {
      Navigator.pop(context, true);
    }
  }

  /// The web layout's card: 920×612, the media (560px) on the left. On a
  /// narrower tablet the card fits the screen and the media keeps its share.
  static const _wideCardSize = Size(920, 612);
  static const _wideMediaShare = 560 / 920;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    if (!KashiLayout.of(context).isPhone) return _wideCard(colors);
    final footer = _learntToggle;
    return Scaffold(
      backgroundColor: colors.ground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Column(
            children: [
              _header(colors),
              // The title tucks up beside the star tip, as in the design;
              // the video frame has no star edge to tuck into.
              Expanded(
                child: Transform.translate(
                  offset: Offset(0, _videoOpen ? 0 : -30),
                  child: _details(colors),
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (footer != null) ...[
                      footer,
                      const SizedBox(height: 10),
                    ],
                    KashiActionButton(
                        label: widget.actionLabel, onPressed: _act),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The "Learnt" switch, on every card of a real move — so it can be
  /// switched on or off wherever the card opens (Library, preview, How to,
  /// Learning mode).
  Widget? get _learntToggle {
    final id = _move.exerciseId;
    return id == null ? null : LearntToggle(exerciseId: id);
  }

  Widget _wideCard(KashiColors colors) {
    final footer = _learntToggle;
    final videoSrc = _move.videoSrc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints.loose(_wideCardSize),
          child: Material(
            key: const ValueKey('learning-card'),
            color: colors.raised,
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    key: const ValueKey('learning-card-media'),
                    width: constraints.maxWidth * _wideMediaShare,
                    child: ColoredBox(
                      color: colors.scene900,
                      child: Stack(fit: StackFit.expand, children: [
                        if (_videoOpen && videoSrc != null)
                          ExerciseDemoVideoPlayer(
                              key: ValueKey(videoSrc), src: videoSrc)
                        else
                          _photo(),
                        if (!_videoOpen && videoSrc != null)
                          Center(
                            child: Material(
                              color: colors.action,
                              child: InkWell(
                                onTap: () => setState(() => _videoOpen = true),
                                child: SizedBox.square(
                                  dimension: 64,
                                  child: Icon(Icons.play_arrow_rounded,
                                      color: colors.onAction,
                                      size: 32,
                                      semanticLabel: 'Play video'),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                  Expanded(
                    child: Stack(children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _details(colors,
                                padding:
                                    const EdgeInsets.fromLTRB(30, 30, 30, 12)),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(30, 0, 30, 28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (footer != null) ...[
                                  footer,
                                  const SizedBox(height: 10),
                                ],
                                KashiActionButton(
                                    label: widget.actionLabel, onPressed: _act),
                              ],
                            ),
                          ),
                        ],
                      ),
                      PositionedDirectional(
                        top: 16,
                        end: 16,
                        child: Material(
                          color: colors.inset,
                          child: IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.maybePop(context, false),
                            icon: const Icon(Icons.close, size: 18),
                            color: colors.textPrimary,
                            style: IconButton.styleFrom(
                              shape: const RoundedRectangleBorder(),
                              fixedSize: const Size(40, 40),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The still, or the pahlevan illustration when there is none.
  Widget _photo() {
    final photo = _move.photo;
    return photo == null
        ? const MovePlaceholder()
        : Image(
            image: photo,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -.4),
            errorBuilder: (_, __, ___) => const MovePlaceholder(),
          );
  }

  Widget _header(KashiColors colors) {
    final top = MediaQuery.paddingOf(context).top;
    final videoSrc = _move.videoSrc;
    return SizedBox(
      height: _photoHeight + 8,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: _photoHeight,
            child: _videoOpen && videoSrc != null
                // While it plays, the photo becomes the full video frame.
                ? ColoredBox(
                    color: colors.scene900,
                    child: ExerciseDemoVideoPlayer(
                        key: ValueKey(videoSrc), src: videoSrc),
                  )
                : ClipPath(
                    clipper: const _KhatamEdgeClipper(),
                    child: ColoredBox(
                      color: colors.scene900,
                      child: _photo(),
                    ),
                  ),
          ),
          PositionedDirectional(
            start: 14,
            top: top + 16,
            child: _SquareButton(
              tooltip: 'Back',
              icon: const BackButtonIcon(),
              onPressed: () => Navigator.maybePop(context, false),
            ),
          ),
          if (_videoOpen)
            PositionedDirectional(
              end: 14,
              top: top + 16,
              child: _SquareButton(
                // The video plays in place of the photo; ✕ leaves the card,
                // like Back.
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.maybePop(context, false),
              ),
            )
          else if (videoSrc != null)
            // The azure play square over the photo's edge, ringed in ground.
            PositionedDirectional(
              end: 12,
              top: _photoHeight - 56,
              child: ColoredBox(
                color: colors.ground,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Material(
                    color: colors.action,
                    child: InkWell(
                      onTap: () => setState(() => _videoOpen = true),
                      child: SizedBox.square(
                        dimension: 60,
                        child: Icon(Icons.play_arrow_rounded,
                            color: colors.onAction,
                            size: 30,
                            semanticLabel: 'Play video'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _details(KashiColors colors,
      {EdgeInsets padding = const EdgeInsets.fromLTRB(22, 0, 22, 12)}) {
    final selected = _selected;
    final reps = selected?.reps ?? _move.target;
    final nameFa = _move.nameFa;
    final minutes = _move.minutes;
    final description = _move.description?.trim();
    final subtitle = [
      if (nameFa != null && nameFa.isNotEmpty)
        Text(nameFa,
            textDirection: TextDirection.rtl,
            style: KashiTextStyles.farsi
                .copyWith(fontSize: 17, color: colors.farsiAccent)),
      if (minutes != null)
        Text('$minutes min',
            style: KashiTextStyles.ui
                .copyWith(fontSize: 15, color: colors.farsiAccent)),
    ];
    return ListView(
      padding: padding,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(selected?.name ?? _move.name,
                style: KashiTextStyles.title
                    .copyWith(fontSize: 30, color: colors.textPrimary)),
            if (reps != null) KashiRepsTag(count: reps),
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              for (final (i, part) in subtitle.indexed) ...[
                if (i > 0)
                  Text('  ·  ',
                      style: KashiTextStyles.body
                          .copyWith(color: colors.farsiAccent)),
                part,
              ],
            ],
          ),
        ],
        if (_hasVariations) ...[
          const SizedBox(height: 14),
          KashiVariationSelector(
            variations: _move.variations,
            index: _variation,
            onChanged: (i) => setState(() => _variation = i),
          ),
        ],
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(description,
              style: KashiTextStyles.body.copyWith(color: colors.textBody)),
        ],
        for (final (i, step) in _move.steps.indexed) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: 22,
                child: ColoredBox(
                  color: colors.inset,
                  child: Center(
                    child: Text('${i + 1}',
                        style: KashiTextStyles.label.copyWith(
                            letterSpacing: 0, color: colors.textPrimary)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(step,
                    style: KashiTextStyles.body.copyWith(
                        fontSize: 14, height: 1.5, color: colors.textBody)),
              ),
            ],
          ),
        ],
        if (_move.cues.isNotEmpty) ...[
          const SizedBox(height: 16),
          const KashiSectionLabel('Pay attention to'),
          const SizedBox(height: 8),
          for (final cue in _move.cues) _Cue(text: cue),
        ],
      ],
    );
  }
}

/// A square ground-coloured icon button over the photo or video.
class _SquareButton extends StatelessWidget {
  const _SquareButton(
      {required this.tooltip, required this.icon, required this.onPressed});

  final String tooltip;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Material(
      color: colors.ground,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon,
        color: colors.textPrimary,
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          fixedSize: const Size(44, 44),
        ),
      ),
    );
  }
}

/// One "pay attention to" point: a small yellow square, then the text.
class _Cue extends StatelessWidget {
  const _Cue({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: SizedBox.square(
                dimension: 6, child: ColoredBox(color: colors.reward)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: KashiTextStyles.body.copyWith(
                    fontSize: 13.5, height: 1.45, color: colors.textBody)),
          ),
        ],
      ),
    );
  }
}

/// The photo ends in the lower half of one large khatam (a 400px star on the
/// 360px phone, tip at the bottom centre). Horizontal points scale with the
/// width; heights are the design's fixed pixels.
class _KhatamEdgeClipper extends CustomClipper<Path> {
  const _KhatamEdgeClipper();

  @override
  Path getClip(Size size) {
    double x(double designX) => designX / 360 * size.width;
    return Path()
      ..addPolygon([
        const Offset(0, 0),
        Offset(size.width, 0),
        Offset(size.width, 82),
        Offset(x(321.4), 120.6),
        Offset(x(321.4), 203.4),
        Offset(x(238.6), 203.4),
        Offset(x(180), 262),
        Offset(x(121.4), 203.4),
        Offset(x(38.6), 203.4),
        Offset(x(38.6), 120.6),
        const Offset(0, 82),
      ], true);
  }

  @override
  bool shouldReclip(_KhatamEdgeClipper oldClipper) => false;
}
