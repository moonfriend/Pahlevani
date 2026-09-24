import 'package:flutter/material.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/presentation/bloc/player/player_mode.dart';

/// Shown when a session card is tapped, before the player opens. Returns the
/// chosen mode, or null if dismissed — callers should treat null as "don't
/// open the player at all", same as backing out of any other dialog.
Future<PlayerMode?> showPlayerModeDialog(BuildContext context) {
  return showDialog<PlayerMode>(
    context: context,
    builder: (_) => const _PlayerModeDialog(),
  );
}

class _PlayerModeDialog extends StatelessWidget {
  const _PlayerModeDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      title: Text('Choose a mode'),
      contentPadding: EdgeInsets.fromLTRB(0, 12, 0, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeOption(
            title: 'Athlete mode',
            subtitle: 'Play straight through',
            mode: PlayerMode.athlete,
          ),
          _ModeOption(
            title: 'Learning Mode',
            subtitle: 'Stop and review each move before it starts',
            mode: PlayerMode.learning,
          ),
          _ModeOption(
            title: 'Zoorkhaneh mode',
            subtitle: 'Loop each move until you tap next',
            mode: PlayerMode.zoorkhaneh,
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.title,
    required this.subtitle,
    required this.mode,
  });

  final String title;
  final String subtitle;
  final PlayerMode mode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: TextStyle(color: colors.onMuted)),
      onTap: () => Navigator.pop(context, mode),
    );
  }
}
