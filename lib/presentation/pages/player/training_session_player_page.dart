import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/bloc/player/audio_player_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/training_session/edit_training_session_page.dart';
import 'package:pahlevani/presentation/widgets/common/persian_pattern.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page shell
// ─────────────────────────────────────────────────────────────────────────────
class AudioPlayerPage extends StatefulWidget {
  const AudioPlayerPage({super.key, required this.trainingSession});
  final TrainingSession trainingSession;

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  late final TrainingSessionPlayerCubit _cubit;
  final _trackListKey = GlobalKey<_TrackListState>();

  @override
  void initState() {
    super.initState();
    _cubit = TrainingSessionPlayerCubit(trainingSession: widget.trainingSession);
    _cubit.loadTracks();
  }

  @override
  void dispose() {
    _cubit.stop();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final accent = colors.accentFor(widget.trainingSession.id);

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: BlocConsumer<TrainingSessionPlayerCubit, AudioPlayerState>(
          listenWhen: (prev, cur) => prev.playingIndex != cur.playingIndex,
          listener: (_, state) => _trackListKey.currentState?.scrollToActive(state.playingIndex),
          builder: (context, state) {
            if (state.isLoading && state.tracks.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.errorMessage != null && state.tracks.isEmpty) {
              return Center(child: Text(state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)));
            }
            return Stack(children: [
              Column(children: [
                _AppBar(session: widget.trainingSession),
                _Stage(state: state, accent: accent, cubit: _cubit),
                _RepCounter(state: state),
                _ProgressBlock(state: state),
                Expanded(child: _TrackList(
                    key: _trackListKey, state: state, accent: accent, cubit: _cubit)),
                _Transport(state: state, cubit: _cubit),
              ]),
              if (state.isFinished)
                _CompletionSheet(
                  session: widget.trainingSession,
                  trackCount: state.tracks.length,
                  onReplay: _cubit.replay,
                  onDone: () => Navigator.pop(context),
                ),
            ]);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App bar
// ─────────────────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  const _AppBar({required this.session});
  final TrainingSession session;

  Future<void> _openEdit(BuildContext context) async {
    final sessionCubit = context.read<TrainingSessionCubit>();
    final detail = sessionCubit.getSessionDetail(session.id);
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditTrainingSessionPage(
        trainingSession: session,
        items: detail?.items ?? const [],
      )),
    );
    if (result != null && context.mounted) {
      final updated = result['session'] as TrainingSession;
      final items = result['items'] as List<ItemDetail>?;
      sessionCubit.updateTrainingSession(updated, items: items);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${updated.title} saved'),
        duration: const Duration(milliseconds: 2200),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
        child: Row(children: [
          _RoundBtn(icon: Icons.arrow_back_rounded, color: cs.onSurface,
              onTap: () => Navigator.pop(context)),
          const SizedBox(width: 4),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PLAY ALONG',
                style: PTextStyles.of(context).playerOverline.copyWith(color: colors.onFaint)),
            Text(session.title,
                style: PTextStyles.of(context).appBarTitle.copyWith(color: cs.onSurface),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          _RoundBtn(icon: Icons.edit_outlined, color: colors.onMuted,
              onTap: () => _openEdit(context)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Media stage (232px)
// ─────────────────────────────────────────────────────────────────────────────
class _Stage extends StatelessWidget {
  const _Stage({required this.state, required this.accent, required this.cubit});
  final AudioPlayerState state;
  final SessionAccent accent;
  final TrainingSessionPlayerCubit cubit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: cubit.togglePlay,
      child: Container(
        height: 232,
        margin: const EdgeInsets.fromLTRB(16, 2, 16, 0),
        decoration: BoxDecoration(
          color: accent.bg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: colors.borderSoft),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned.fill(child: PersianPattern(color: accent.fg, opacity: 0.5, tileSize: 110)),
          // Exercise name — bottom left
          Positioned(
            left: 16, bottom: 16, right: 80,
            child: Text(state.currentTrack?.title ?? '',
                style: PTextStyles.of(context).playerExLatin.copyWith(color: cs.onSurface),
                maxLines: 2),
          ),
          // Paused overlay
          if (!state.isPlaying)
            Positioned.fill(
              child: ColoredBox(
                color: colors.scrim,
                child: Center(
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                        color: cs.surface, shape: BoxShape.circle,
                        boxShadow: colors.shadowPop),
                    alignment: Alignment.center,
                    child: Icon(Icons.play_arrow_rounded, size: 34, color: cs.primary),
                  ),
                ),
              ),
            ),
          // Now-playing pill
          if (state.isPlaying)
            Positioned(
              right: 14, bottom: 14,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
                decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(99),
                    boxShadow: colors.shadowCard),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _Equalizer(color: accent.fg),
                  const SizedBox(width: 8),
                  Text('Pause',
                      style: TextStyle(fontFamily: PFonts.ui, fontWeight: FontWeight.w700,
                          fontSize: 12, color: cs.onSurface)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rep counter — the signature moment
// ─────────────────────────────────────────────────────────────────────────────
class _RepCounter extends StatefulWidget {
  const _RepCounter({required this.state});
  final AudioPlayerState state;

  @override
  State<_RepCounter> createState() => _RepCounterState();
}

class _RepCounterState extends State<_RepCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.28).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    TweenSequenceItem(
        tween: Tween(begin: 1.28, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 65),
  ]).animate(_ctrl);
  late final Animation<double> _flash = Tween(begin: 0.85, end: 0.0)
      .animate(CurvedAnimation(parent: _ctrl,
          curve: const Interval(0, 0.6, curve: Curves.easeOut)));

  int _lastRep = 0;

  int _computeRep(AudioPlayerState s) {
    if (s.logicalDuration.inMilliseconds <= 0) return 1;
    final total = s.currentTrack?.effectiveRepetitions ?? 1;
    final secondsPerRep = s.logicalDuration.inMilliseconds / total / 1000;
    if (secondsPerRep <= 0) return 1;
    return ((s.logicalPosition.inMilliseconds / 1000) / secondsPerRep).floor() + 1;
  }

  @override
  void didUpdateWidget(_RepCounter old) {
    super.didUpdateWidget(old);
    final total = widget.state.currentTrack?.effectiveRepetitions ?? 1;
    final rep = _computeRep(widget.state).clamp(1, total);
    if (_lastRep != 0 && rep != _lastRep) {
      HapticFeedback.selectionClick();
      _ctrl.forward(from: 0);
    }
    _lastRep = rep;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    if (s.currentTrack == null || s.logicalDuration.inMilliseconds == 0) {
      return const SizedBox(height: 16);
    }
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final track = s.currentTrack!;
    final total = track.effectiveRepetitions;
    final isCustom = track.effectiveRepetitions != (track.defaultRepetitions ?? 1);
    final rep = _computeRep(s).clamp(1, total);
    final pillBg  = isCustom ? colors.repCustomBg  : colors.repDefaultBg;
    final pillFg  = isCustom ? colors.repCustom     : colors.repDefault;
    final glow = isCustom
        ? colors.repCustom.withValues(alpha: 0.4)
        : colors.repDefault.withValues(alpha: 0.36);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(99),
              boxShadow: [BoxShadow(color: glow, blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Stack(alignment: Alignment.center, children: [
              // Flash overlay
              AnimatedBuilder(
                animation: _flash,
                builder: (_, __) => Container(
                  decoration: BoxDecoration(
                    color: pillFg.withValues(alpha: _flash.value),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 20, 9),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: pillFg, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('$rep',
                        style: TextStyle(fontFamily: PFonts.ui, fontWeight: FontWeight.w800,
                            fontSize: 15, color: pillBg)),
                  ),
                  const SizedBox(width: 10),
                  RichText(text: TextSpan(
                    style: PTextStyles.of(context).repPill.copyWith(color: pillFg),
                    children: [
                      TextSpan(text: 'Rep $rep '),
                      TextSpan(text: 'of $total',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      if (isCustom)
                        const TextSpan(text: '  · custom',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                    ],
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress block
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.state});
  final AudioPlayerState state;

  static String _clock(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    final dur = state.logicalDuration;
    final pos = state.logicalPosition;
    final progress = dur.inMilliseconds > 0
        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(state.currentTrack?.title ?? '',
                  style: TextStyle(fontFamily: PFonts.ui, fontWeight: FontWeight.w700,
                      fontSize: 13.5, color: cs.onSurface),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text('${_clock(pos)} / ${_clock(dur)}',
                style: PTextStyles.of(context).playerTime.copyWith(color: colors.onMuted)),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress, minHeight: 6,
            backgroundColor: colors.surface3,
            valueColor: AlwaysStoppedAnimation(colors.repDefault),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Track list
// ─────────────────────────────────────────────────────────────────────────────
class _TrackList extends StatefulWidget {
  const _TrackList({super.key, required this.state, required this.accent, required this.cubit});
  final AudioPlayerState state;
  final SessionAccent accent;
  final TrainingSessionPlayerCubit cubit;

  @override
  State<_TrackList> createState() => _TrackListState();
}

class _TrackListState extends State<_TrackList> {
  final _scrollCtrl = ScrollController();
  final _itemKeys = <int, GlobalKey>{};

  void scrollToActive(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[index];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(key!.currentContext!,
            duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    final tracks = widget.state.tracks;
    final activeIndex = widget.state.playingIndex;
    final isPlaying = widget.state.isPlaying;

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        _itemKeys[i] ??= GlobalKey();
        final track = tracks[i];
        final active = i == activeIndex;
        final isCustom = track.effectiveRepetitions != (track.defaultRepetitions ?? 1);
        final repFg = isCustom ? colors.repCustom   : colors.repDefault;
        final repBg = isCustom ? colors.repCustomBg : colors.repDefaultBg;

        return GestureDetector(
          key: _itemKeys[i],
          onTap: () => widget.cubit.setIndexAndPlay(i),
          child: Container(
            height: 70,
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: active ? colors.surface2 : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: active ? widget.accent.fg : colors.surface3,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text('${i + 1}', style: TextStyle(
                    fontFamily: PFonts.ui, fontWeight: FontWeight.w700, fontSize: 13,
                    color: active ? cs.onPrimary : colors.onMuted,
                    fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(track.title, style: TextStyle(
                      fontFamily: PFonts.ui,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 14.5,
                      color: active ? cs.onSurface : colors.onMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${track.effectiveRepetitions} reps',
                      style: PTextStyles.of(context).trackRowGloss.copyWith(color: colors.onFaint)),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: repBg, borderRadius: BorderRadius.circular(99)),
                child: Text('${track.effectiveRepetitions}×',
                    style: PTextStyles.of(context).repChip.copyWith(color: repFg)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 22,
                child: active
                    ? Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 18, color: widget.accent.fg)
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom transport
// ─────────────────────────────────────────────────────────────────────────────
class _Transport extends StatelessWidget {
  const _Transport({required this.state, required this.cubit});
  final AudioPlayerState state;
  final TrainingSessionPlayerCubit cubit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    final atStart = state.playingIndex <= 0;
    final atEnd = state.playingIndex >= state.tracks.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [colors.bg, colors.bg.withValues(alpha: 0)],
          stops: const [0.6, 1.0],
        ),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _TransportBtn(size: 52, icon: Icons.keyboard_arrow_up_rounded,
            enabled: !atStart, colors: colors, onTap: cubit.prev),
        const SizedBox(width: 28),
        GestureDetector(
          onTap: cubit.togglePlay,
          child: Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(24),
              boxShadow: colors.shadowPop,
            ),
            alignment: Alignment.center,
            child: Icon(
              state.isFinished
                  ? Icons.replay_rounded
                  : (state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
              size: 30, color: cs.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: 28),
        _TransportBtn(size: 52, icon: Icons.keyboard_arrow_down_rounded,
            enabled: !atEnd, colors: colors, onTap: cubit.next),
      ]),
    );
  }
}

class _TransportBtn extends StatelessWidget {
  const _TransportBtn({
    required this.size, required this.icon,
    required this.enabled, required this.colors, required this.onTap,
  });
  final double size;
  final IconData icon;
  final bool enabled;
  final PahlevaniColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: colors.surface2,
            shape: BoxShape.circle,
            border: Border.all(color: colors.borderSoft),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 24, color: enabled ? cs.onSurface : colors.onFaint),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Completion sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CompletionSheet extends StatelessWidget {
  const _CompletionSheet({
    required this.session,
    required this.trackCount,
    required this.onReplay,
    required this.onDone,
  });

  final TrainingSession session;
  final int trackCount;
  final VoidCallback onReplay;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(children: [
          // Scrim
          Positioned.fill(
            child: GestureDetector(
              onTap: onDone,
              child: AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 250),
                child: ColoredBox(color: colors.scrim),
              ),
            ),
          ),
          // Sheet slides up from bottom
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Drag handle
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(9)),
                ),
                // Gold banner with pattern
                Container(
                  height: 84,
                  decoration: BoxDecoration(
                    color: colors.primaryBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(alignment: Alignment.center, children: [
                    Positioned.fill(child: PersianPattern(color: cs.primary, opacity: 0.5, tileSize: 84)),
                    Text('خسته نباشی',
                        style: PTextStyles.of(context).sheetFarsi.copyWith(color: cs.primary),
                        textDirection: TextDirection.rtl),
                  ]),
                ),
                const SizedBox(height: 18),
                Text('Session complete',
                    style: PTextStyles.of(context).dialogTitle.copyWith(color: cs.onSurface),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: 'You moved through all $trackCount exercises of ',
                        style: TextStyle(fontFamily: PFonts.ui, fontSize: 14, color: colors.onMuted, height: 1.5),
                      ),
                      TextSpan(
                        text: session.title,
                        style: TextStyle(fontFamily: PFonts.ui, fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface),
                      ),
                      TextSpan(
                        text: '. Khaste nabâshi — may you never tire.',
                        style: TextStyle(fontFamily: PFonts.ui, fontSize: 14, color: colors.onMuted, height: 1.5),
                      ),
                    ]),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onDone,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: colors.surface2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.borderSoft),
                        ),
                        alignment: Alignment.center,
                        child: Text('Done',
                            style: PTextStyles.of(context).buttonLabel.copyWith(color: cs.onSurface)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: onReplay,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.replay_rounded, size: 20, color: cs.onPrimary),
                          const SizedBox(width: 8),
                          Text('Again',
                              style: PTextStyles.of(context).buttonLabel.copyWith(color: cs.onPrimary)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(width: 44, height: 44,
        child: Icon(icon, size: 24, color: color)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated equalizer bars
// ─────────────────────────────────────────────────────────────────────────────
class _Equalizer extends StatefulWidget {
  const _Equalizer({required this.color});
  final Color color;

  @override
  State<_Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<_Equalizer> with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) => AnimationController(
      vsync: this, duration: Duration(milliseconds: 700 + i * 180))..repeat(reverse: true));
    _anims = _ctrls.map((c) =>
        Tween(begin: 4.0, end: 14.0).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut))
    ).toList();
  }

  @override
  void dispose() {
    for (final c in _ctrls) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 14,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) => Padding(
        padding: EdgeInsets.only(left: i > 0 ? 2.5 : 0),
        child: AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Container(
            width: 3, height: _anims[i].value,
            decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      )),
    ),
  );
}
