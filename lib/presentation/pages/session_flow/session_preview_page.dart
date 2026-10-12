import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../core/theme/kashi/kashi_assets.dart';
import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_palette.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../../domain/entities/audio_catalog/morshed.dart';
import '../../../domain/entities/training_session/prescription.dart';
import '../../../domain/entities/training_session/session_details.dart';
import '../../../domain/entities/training_session/training_session.dart';
import '../../../domain/repositories/download_repository.dart';
import '../../../domain/usecases/audio_catalog/effective_morshed.dart';
import '../../../domain/usecases/player/resolve_move_media.dart';
import '../../bloc/audio_catalog/audio_catalog_cubit.dart';
import '../audio_catalog/choose_morshed_flow.dart';
import '../../bloc/player/player_mode.dart';
import '../../bloc/training_session/training_session_cubit.dart';
import '../../widgets/exercise_image_provider.dart';
import '../../widgets/kashi/kashi_action_button.dart';
import '../../widgets/kashi/khatam.dart';
import '../../layout/kashi_layout.dart';
import '../library/learning_card_page.dart';
import 'session_start.dart';

/// Opens [session]'s preview — the way into every session. Provides the
/// app-wide morshed choice to the new route (the shell's providers don't
/// reach pushed routes).
Future<void> openSessionPreview(
        BuildContext context, TrainingSession session) =>
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: getIt<AudioCatalogCubit>()..load(),
          child: SessionPreviewPage(session: session),
        ),
      ),
    );

/// What you are about to do, and with which morshed: the session's header
/// with a framed still, the morshed dropdown, the move list (a move a trainer
/// flagged for counting shows its reps; tapping a move opens its learning
/// card) and two start buttons: Educational (Learning mode — pauses before
/// each move not yet learnt) and Only follow along (Athlete mode).
///
/// Zoorkhaneh mode is not offered here; it lives in the session's own menu.
/// Expects [TrainingSessionCubit] and [AudioCatalogCubit] above it.
class SessionPreviewPage extends StatefulWidget {
  const SessionPreviewPage({super.key, required this.session, this.onStart});

  final TrainingSession session;

  /// Starts the session; defaults to [startSession]. For tests.
  final void Function(BuildContext context, PlayerMode mode)? onStart;

  @override
  State<SessionPreviewPage> createState() => _SessionPreviewPageState();
}

class _SessionPreviewPageState extends State<SessionPreviewPage> {
  void _start(PlayerMode mode) {
    final onStart = widget.onStart;
    if (onStart != null) {
      onStart(context, mode);
    } else {
      startSession(context, widget.session, mode);
    }
  }

  Future<void> _openMove(ItemDetail detail) async {
    final (media, videoReady) =
        await ResolveMoveMedia(getIt<DownloadRepository>())(
            detail.exercise.media,
            useRemoteMedia: kIsWeb);
    if (!mounted) return;
    final seconds =
        context.read<TrainingSessionCubit>().moveDurationSeconds(detail.item);
    await showLearningCard(
      context,
      LearningMove.fromExercise(
        detail.exercise,
        media: media,
        videoReady: videoReady,
        target: _countedTarget(detail),
        minutes: seconds == null ? null : _wholeMinutes(seconds),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final sessions = context.watch<TrainingSessionCubit>();
    final moves = sessions.getSessionDetail(widget.session.id)?.items ??
        const <ItemDetail>[];
    final seconds = [
      for (final m in moves) sessions.moveDurationSeconds(m.item),
    ];

    final totalSeconds =
        seconds.contains(null) ? null : seconds.fold<int>(0, (a, s) => a + s!);
    final moveRows = [
      if (moves.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text('This session has no moves yet.',
              style: KashiTextStyles.body.copyWith(color: colors.textMuted)),
        ),
      for (var i = 0; i < moves.length; i++)
        _MoveRow(
          number: i + 1,
          name: moves[i].exercise.name,
          reps: _countedTarget(moves[i]),
          seconds: seconds[i],
          onTap: () => _openMove(moves[i]),
        ),
    ];
    final startButtons = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KashiActionButton(
          label: 'Educational',
          onPressed: moves.isEmpty ? null : () => _start(PlayerMode.learning),
        ),
        const SizedBox(height: 8),
        KashiActionButton(
          label: 'Only follow along',
          onPressed: moves.isEmpty ? null : () => _start(PlayerMode.athlete),
        ),
      ],
    );

    if (!KashiLayout.of(context).isPhone) {
      return _wide(colors, moves, totalSeconds, moveRows, startButtons);
    }
    return Scaffold(
      backgroundColor: colors.ground,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _Header(
                    session: widget.session,
                    moves: moves,
                    totalSeconds: totalSeconds),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Column(children: moveRows),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 10, 16, 22),
            child: startButtons,
          ),
        ],
      ),
    );
  }

  /// Tablet and web: the lajvard session panel (header, still, morshed and
  /// the start buttons) on the left, the moves on the right.
  Widget _wide(
    KashiColors colors,
    List<ItemDetail> moves,
    int? totalSeconds,
    List<Widget> moveRows,
    Widget startButtons,
  ) {
    return Scaffold(
      backgroundColor: colors.ground,
      body: LayoutBuilder(builder: (context, constraints) {
        final panel = (constraints.maxWidth * .45).clamp(300.0, 560.0);
        // Narrow tablets keep the move list readable with smaller margins.
        final listSide = constraints.maxWidth - panel < 420 ? 20.0 : 40.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: panel,
              child: ColoredBox(
                color: KashiPalette.lajvard700,
                child: CustomPaint(
                  painter: const _KhatamOutlinePattern(),
                  child: SafeArea(
                    right: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: _Header(
                              session: widget.session,
                              moves: moves,
                              totalSeconds: totalSeconds,
                              embedded: true,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
                          child: startButtons,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SafeArea(
                left: false,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(listSide, 40, listSide, 32),
                  children: [
                    Text('MOVES · TAP ONE TO WATCH HOW',
                        style: KashiTextStyles.label
                            .copyWith(color: colors.textMuted)),
                    const SizedBox(height: 14),
                    ...moveRows,
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// The reps a counted move asks for; null when it isn't counted.
int? _countedTarget(ItemDetail detail) => detail.item.isTracked
    ? switch (detail.item.prescription) {
        RepsPresc(:final count) => count,
        _ => null,
      }
    : null;

int _wholeMinutes(int seconds) => (seconds / 60).round().clamp(1, 999);

/// The row's effort: reps of a counted move, then the time.
String _effort(int? reps, int? seconds) => [
      if (reps != null) '$reps reps',
      if (seconds != null) _minutes(seconds),
    ].join(' · ');

String _minutes(int seconds) => '${_wholeMinutes(seconds)} min';

class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.moves,
    required this.totalSeconds,
    this.embedded = false,
  });

  final TrainingSession session;
  final List<ItemDetail> moves;
  final int? totalSeconds;

  /// Inside the wide layout's lajvard panel, which paints the ground and
  /// the safe area; the still is taller there.
  final bool embedded;

  /// A still from the first move that has one: its photo or video poster.
  String? get _still {
    for (final m in moves) {
      final media = m.exercise.media;
      final src = media.type == 'photo' ? media.src : media.poster;
      if (src != null && src.isNotEmpty) return src;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final still = _still;
    final meta = [
      if (totalSeconds != null) _minutes(totalSeconds!),
      '${moves.length} ${moves.length == 1 ? 'move' : 'moves'}',
    ].join(' · ');
    final content = Padding(
      padding: embedded
          ? const EdgeInsets.fromLTRB(24, 24, 24, 18)
          : const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Material(
                color: Colors.white.withValues(alpha: .1),
                child: InkWell(
                  onTap: () => Navigator.maybePop(context),
                  child: const SizedBox.square(
                    dimension: 44,
                    child:
                        Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                ),
              ),
              Text('SESSION',
                  style: KashiTextStyles.label
                      .copyWith(color: KashiPalette.yellow400)),
            ],
          ),
          const SizedBox(height: 12),
          _FramedStill(src: still, height: embedded ? 240 : 140),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(session.title,
                    style: KashiTextStyles.heading
                        .copyWith(fontSize: 26, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Text(meta,
                  style: KashiTextStyles.ui
                      .copyWith(fontSize: 12.5, color: KashiPalette.sky300)),
            ],
          ),
          const SizedBox(height: 12),
          const _MorshedDropdown(),
        ],
      ),
    );
    if (embedded) return content;
    return ColoredBox(
      color: KashiPalette.lajvard700,
      child: CustomPaint(
        painter: const _KhatamOutlinePattern(),
        child: SafeArea(bottom: false, child: content),
      ),
    );
  }
}

/// The session still in a 3px yellow, 3px lajvard, 1px turquoise frame;
/// the pahlevan illustration when no move has a still.
class _FramedStill extends StatelessWidget {
  const _FramedStill({required this.src, required this.height});

  final String? src;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 7),
      height: height,
      decoration: const BoxDecoration(boxShadow: [
        BoxShadow(color: KashiPalette.turquoise500, spreadRadius: 7),
        BoxShadow(color: KashiPalette.lajvard700, spreadRadius: 6),
        BoxShadow(color: KashiPalette.yellow400, spreadRadius: 3),
      ]),
      child: ClipRect(
        child: src != null
            ? Image(
                image: ExerciseImageProvider(src!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback,
              )
            : _fallback,
      ),
    );
  }

  static final _fallback = ColoredBox(
    color: KashiPalette.lajvard500,
    child: Image.asset(KashiAssets.pahlevanMale, fit: BoxFit.contain),
  );
}

/// "Morshed ♪ Ali ▾" — sets the app-wide morshed choice (the same one as
/// Profile → Morshed voice), then refreshes the move durations.
class _MorshedDropdown extends StatelessWidget {
  const _MorshedDropdown();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AudioCatalogCubit>().state;
    if (state is! AudioCatalogLoaded || state.morsheds.isEmpty) {
      return const SizedBox.shrink();
    }
    final effectiveId = effectiveMorshedId(
        selectedId: state.selectedMorshedId, morsheds: state.morsheds);
    final current = state.morsheds
        .where((m) => m.id == effectiveId)
        .cast<Morshed?>()
        .firstWhere((_) => true, orElse: () => null);

    Future<void> pick(int id) async {
      final sessions = context.read<TrainingSessionCubit>();
      await chooseMorshed(
          context, state.morsheds.firstWhere((m) => m.id == id));
      await sessions.refreshAudioSelection();
    }

    return PopupMenuButton<int>(
      tooltip: 'Choose morshed',
      onSelected: pick,
      position: PopupMenuPosition.under,
      shape: const RoundedRectangleBorder(),
      color: KashiPalette.plaster100,
      itemBuilder: (_) => [
        for (final m in state.morsheds)
          PopupMenuItem(
            value: m.id,
            child: Text(m.name,
                style: KashiTextStyles.ui
                    .copyWith(fontSize: 15, color: KashiPalette.lajvard700)),
          ),
      ],
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        color: Colors.white.withValues(alpha: .1),
        child: Row(
          children: [
            Text('Morshed',
                style: KashiTextStyles.ui
                    .copyWith(fontSize: 12, color: KashiPalette.sky300)),
            const SizedBox(width: 10),
            const Icon(Icons.music_note, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Expanded(
              child: Text(current?.name ?? 'Choose',
                  overflow: TextOverflow.ellipsis,
                  style: KashiTextStyles.ui.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
            const Icon(Icons.arrow_drop_down, color: KashiPalette.yellow400),
          ],
        ),
      ),
    );
  }
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({
    required this.number,
    required this.name,
    required this.reps,
    required this.seconds,
    required this.onTap,
  });

  final int number;
  final String name;

  /// Target reps of a counted move; null when it isn't counted.
  final int? reps;
  final int? seconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.line))),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              color: KashiPalette.lajvard500,
              alignment: Alignment.center,
              child: Text('$number',
                  style: KashiTextStyles.ui.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name,
                  style: KashiTextStyles.ui
                      .copyWith(fontSize: 14, color: colors.textPrimary)),
            ),
            // "20 reps · 3 min": plain text, like the time alone.
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44),
              child: Text(_effort(reps, seconds),
                  textAlign: TextAlign.end,
                  style: KashiTextStyles.ui.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: colors.textMuted)),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// The session header's outline khatam pattern (34px repeat, #1A3578).
class _KhatamOutlinePattern extends CustomPainter {
  const _KhatamOutlinePattern();

  static const _cell = 34.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF1A3578);
    final star = khatamPath(const Size(_cell, _cell));
    canvas.clipRect(Offset.zero & size);
    for (var y = 0.0; y < size.height; y += _cell) {
      for (var x = 0.0; x < size.width; x += _cell) {
        canvas.drawPath(star.shift(Offset(x, y)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_KhatamOutlinePattern oldDelegate) => false;
}
