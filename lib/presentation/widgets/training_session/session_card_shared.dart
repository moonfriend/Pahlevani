import 'package:flutter/material.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/widgets/common/difficulty_pips.dart';

class SessionMetaRow extends StatelessWidget {
  const SessionMetaRow({
    super.key,
    required this.itemCount,
    required this.duration,
    required this.difficulty,
  });
  final int itemCount;
  final int? duration;
  final int difficulty;

  String _fmt(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final style =
        PTextStyles.of(context).cardMeta.copyWith(color: colors.onMuted);
    final dot = Container(
        width: 3,
        height: 3,
        decoration:
            BoxDecoration(color: colors.onFaint, shape: BoxShape.circle));

    return Row(children: [
      Icon(Icons.queue_music_rounded, size: 15, color: colors.onMuted),
      const SizedBox(width: 5),
      Text('$itemCount tracks', style: style),
      if (duration != null) ...[
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: dot),
        Text(_fmt(duration!), style: style),
      ],
      const Spacer(),
      DifficultyPips(level: difficulty),
    ]);
  }
}

class YoursChip extends StatelessWidget {
  const YoursChip({super.key, required this.colors});
  final PahlevaniColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: colors.tealBg, borderRadius: BorderRadius.circular(99)),
      child: Text('Yours',
          style: TextStyle(
              fontFamily: PFonts.ui,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: colors.teal,
              letterSpacing: 0.3)),
    );
  }
}
