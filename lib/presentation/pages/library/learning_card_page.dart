import 'package:flutter/material.dart';

import '../../../core/release_features.dart';
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
import '../../widgets/player/fullscreen_mode.dart';
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
    this.followAlongVideoSrc,
    this.videoComingSoon = false,
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

  /// A session's move. [media] is the already-resolved media (local file
  /// where downloaded); it gives the card its still — the photo, or the
  /// follow-along video's poster. The card's main video is the learning
  /// video, [learningVideoSrc] (see `ResolveLearningVideo`); the follow-along
  /// video is offered beside it when [followAlongReady] (it can play: on the
  /// device, or streamed on the web — see `ResolveMoveMedia`). [target] is
  /// set for a counted move.
  factory LearningMove.fromExercise(
    Exercise exercise, {
    required ExerciseMedia media,
    required String? learningVideoSrc,
    bool followAlongReady = false,
    int? target,
    int? minutes,
  }) {
    final followAlong = media.type == 'video' ? media.src : null;
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
      videoSrc: (learningVideoSrc == null || learningVideoSrc.isEmpty)
          ? null
          : learningVideoSrc,
      followAlongVideoSrc:
          (followAlongReady && followAlong != null && followAlong.isNotEmpty)
              ? followAlong
              : null,
      // Whether the move has a learning video at all — not whether it can
      // play right now (it may simply not be downloaded yet).
      videoComingSoon: exercise.videoUrl?.isEmpty ?? true,
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

  /// The playable learning video (local file, or URL on web); null hides the
  /// play button.
  final String? videoSrc;

  /// The playable follow-along video (the one the player shows during a
  /// session); when set, a Learning / Follow-along toggle switches to it.
  final String? followAlongVideoSrc;

  /// No learning video has been made for this move yet: the still carries
  /// a "coming soon" label asking for support. Never set for the Library's
  /// placeholder samples.
  final bool videoComingSoon;
}

/// Opens [move]'s learning card as a pop-up over the dimmed page behind it:
/// a one-column card on phones, a two-column card on tablets and in the web
/// layout. Resolves to true when the action was pressed, false when the card
/// was closed (system Back or a tap beside it) — so a caller acts only once
/// the card has fully closed. The video starts straight away, as the design
/// asks when the card is opened from a session.
///
/// [hint] is a line above the card; a session passes [learnFirstHint].
Future<bool> showLearningCard(
  BuildContext context,
  LearningMove move, {
  String actionLabel = 'Got it',
  String? hint,
}) async {
  final result = await pushLearningCard(
    context,
    LearningCardPage(
      move: move,
      actionLabel: actionLabel,
      autoplayVideo: true,
      hint: hint,
    ),
  );
  return result ?? false;
}

/// Shows [page] as a pop-up over the dimmed current page. The card has no
/// close button of its own: its action, system Back or a tap beside it.
Future<bool?> pushLearningCard(BuildContext context, LearningCardPage page) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: page.move.name,
    // Light enough that the page behind stays visible: a pop-up over it.
    barrierColor: const Color(0x6B060C1E), // rgba(6,12,30,.42)
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => page,
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// The line above a learning card opened from a session.
const learnFirstHint = 'First learn the move, then do it.';

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
    this.hint,
    this.showVariations = ReleaseFeatures.moveVariations,
  });

  /// The Library's card: "Let’s go" (practising one move) isn't built yet.
  factory LearningCardPage.sample(SampleMove move,
          {Key? key, bool showVariations = ReleaseFeatures.moveVariations}) =>
      LearningCardPage(
        key: key,
        showVariations: showVariations,
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

  /// A short line above the card (e.g. [learnFirstHint]); none when null.
  final String? hint;

  /// Lighter/Harder; off in release 1 ([ReleaseFeatures.moveVariations]).
  final bool showVariations;

  @override
  State<LearningCardPage> createState() => _LearningCardPageState();
}

class _LearningCardPageState extends State<LearningCardPage> {
  /// The standard variation sits in the middle of the list.
  late int _variation = widget.move.variations.length ~/ 2;

  late bool _videoOpen = widget.autoplayVideo && widget.move.videoSrc != null;

  /// Which of the move's videos the media shows (see [_VideoToggle]).
  _CardVideo _showing = _CardVideo.learning;

  /// The video fills the screen (⛶, or a phone held sideways). A key per
  /// video moves its one player between the card and full screen, and
  /// switching videos starts the other one afresh.
  bool _fullscreen = false;
  bool? _landscapePhone;
  final _videoKeys = {for (final v in _CardVideo.values) v: GlobalKey()};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Turning the phone follows the rotation; the button decides in between.
    final landscape = isLandscapePhone(MediaQuery.sizeOf(context));
    if (landscape != _landscapePhone) {
      _landscapePhone = landscape;
      _fullscreen = landscape;
    }
  }

  void _toggleFullscreen() => setState(() => _fullscreen = !_fullscreen);

  static const _photoHeight = 210.0;
  static const _maxWidth = 440.0;

  /// Keeps the phone card clearly smaller than the page behind it, so it
  /// reads as a pop-up over that page.
  static const _phoneCardMargin =
      EdgeInsets.symmetric(horizontal: 28, vertical: 56);

  LearningMove get _move => widget.move;

  /// The video playing in the media, if any: the follow-along one once
  /// chosen, else the learning video once opened.
  String? get _playingSrc => switch (_showing) {
        _CardVideo.followAlong => _move.followAlongVideoSrc,
        _CardVideo.learning => _videoOpen ? _move.videoSrc : null,
      };

  bool get _hasToggle => _move.followAlongVideoSrc != null;

  /// Below the toggle when it is shown, so nothing sits under it.
  double get _controlsTop => _hasToggle ? 56 : 8;

  /// The play button over the still (learning video not started yet).
  bool get _offersPlay =>
      _showing == _CardVideo.learning && !_videoOpen && _move.videoSrc != null;
  bool get _hasVariations =>
      widget.showVariations && _move.variations.isNotEmpty;
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
    final playing = _playingSrc;
    if (_fullscreen && playing != null) return _fullscreenVideo(playing);
    if (!KashiLayout.of(context).isPhone) return _wideCard(colors);
    final footer = _learntToggle;
    return SafeArea(
      minimum: _phoneCardMargin,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: _withHint(Material(
            key: const ValueKey('learning-card'),
            color: colors.ground,
            clipBehavior: Clip.hardEdge,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(colors),
                // The title tucks up beside the star tip, as in the design;
                // the video frame has no star edge to tuck into.
                Flexible(
                  child: Transform.translate(
                    offset: Offset(0, _playingSrc != null ? 0 : -30),
                    child: _details(colors, shrinkWrap: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
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
          )),
        ),
      ),
    );
  }

  /// The video and its ⛶ / ✕ button; the same player in the card and in
  /// full screen.
  Widget _video(String src) => Stack(fit: StackFit.expand, children: [
        ExerciseDemoVideoPlayer(
            key: _videoKeys[_showing],
            src: src,
            controlsTop: _fullscreen ? 8 : _controlsTop),
        // Beside the speed button (top right, 48px wide).
        Positioned(
          top: _fullscreen ? 8 : _controlsTop,
          right: 64,
          child: FullscreenToggleButton(
              fullscreen: _fullscreen, onPressed: _toggleFullscreen),
        ),
      ]);

  /// The video alone on black. Back leaves full screen, not the card.
  Widget _fullscreenVideo(String src) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _fullscreen = false);
        },
        child: FullscreenScope(
          key: const ValueKey('learning-card-fullscreen'),
          child: _video(src),
        ),
      );

  /// [card] with the [LearningCardPage.hint] above it, on the dimmed page.
  Widget _withHint(Widget card) {
    final hint = widget.hint;
    if (hint == null) return card;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(hint,
            textAlign: TextAlign.center,
            style: KashiTextStyles.ui.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 10),
        Flexible(child: card),
      ],
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
    final playing = _playingSrc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints.loose(_wideCardSize),
          child: _withHint(Material(
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
                        if (playing != null) _video(playing) else _photo(),
                        if (_offersPlay)
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
                        if (_hasToggle) _toggleAt(),
                      ]),
                    ),
                  ),
                  Expanded(
                    child: Column(
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
                  ),
                ],
              ),
            ),
          )),
        ),
      ),
    );
  }

  /// The still, or the pahlevan illustration when there is none; labelled
  /// "coming soon" while the move has no learning video.
  Widget _photo() {
    final photo = _move.photo;
    final still = photo == null
        ? const MovePlaceholder()
        : Image(
            image: photo,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -.4),
            errorBuilder: (_, __, ___) => const MovePlaceholder(),
          );
    if (!_move.videoComingSoon) return still;
    return Stack(fit: StackFit.expand, children: [
      still,
      // Below the toggle when it is shown.
      PositionedDirectional(
          top: _hasToggle ? 56 : 14,
          start: 14,
          end: 14,
          child: _ComingSoonLabel(offersFollowAlong: _hasToggle)),
    ]);
  }

  /// The Learning / Follow-along toggle, at the top right of the media.
  Widget _toggleAt() => PositionedDirectional(
        top: 8,
        end: 8,
        child: _VideoToggle(
          showing: _showing,
          onChanged: (video) => setState(() => _showing = video),
        ),
      );

  Widget _header(KashiColors colors) {
    final playing = _playingSrc;
    return SizedBox(
      height: _photoHeight + 8,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: _photoHeight,
            child: playing != null
                // While it plays, the photo becomes the full video frame.
                ? ColoredBox(
                    color: colors.scene900,
                    child: _video(playing),
                  )
                : ClipPath(
                    clipper: const _KhatamEdgeClipper(),
                    child: ColoredBox(
                      color: colors.scene900,
                      child: _photo(),
                    ),
                  ),
          ),
          if (_hasToggle) _toggleAt(),
          if (_offersPlay)
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
      {EdgeInsets padding = const EdgeInsets.fromLTRB(22, 0, 22, 12),
      bool shrinkWrap = false}) {
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
      shrinkWrap: shrinkWrap,
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

/// The label on a still whose move has no learning video yet.
class _ComingSoonLabel extends StatelessWidget {
  const _ComingSoonLabel({required this.offersFollowAlong});

  /// The card has the follow-along video to offer meanwhile.
  final bool offersFollowAlong;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xCC0B1638)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Learning video coming soon',
                  style: KashiTextStyles.ui.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 2),
              if (offersFollowAlong)
                Text('For now, you can watch the follow-along video.',
                    style: KashiTextStyles.ui
                        .copyWith(fontSize: 12.5, color: Colors.white)),
              Text('Support us so we can make more, faster.',
                  style: KashiTextStyles.ui
                      .copyWith(fontSize: 12.5, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two videos a learning card can show.
enum _CardVideo { learning, followAlong }

/// The small Learning / Follow-along switch over the card's media.
class _VideoToggle extends StatelessWidget {
  const _VideoToggle({required this.showing, required this.onChanged});

  final _CardVideo showing;
  final ValueChanged<_CardVideo> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return SegmentedButton<_CardVideo>(
      key: const ValueKey('learning-card-video-toggle'),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: _CardVideo.learning, label: Text('Learning')),
        ButtonSegment(
            value: _CardVideo.followAlong, label: Text('Follow-along')),
      ],
      selected: {showing},
      onSelectionChanged: (selection) => onChanged(selection.single),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding:
            const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
        textStyle: WidgetStatePropertyAll(KashiTextStyles.ui
            .copyWith(fontSize: 12.5, fontWeight: FontWeight.w700)),
        // Readable over any frame of the still or the video.
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? colors.action
                : const Color(0xCC0B1638)),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? colors.onAction
                : Colors.white),
        side: const WidgetStatePropertyAll(BorderSide(color: Colors.white38)),
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
