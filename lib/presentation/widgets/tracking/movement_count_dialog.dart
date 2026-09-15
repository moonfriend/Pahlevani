import 'package:flutter/material.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_count.dart';

/// Shown right after a session finishes, when it contained at least one
/// tracked item. Prefilled with the programmed total for each movement
/// present; the user can adjust before saving. Returns the edited counts, or
/// null if dismissed without an explicit Save (callers should fall back to
/// the prefilled defaults in that case, so a session's totals are never
/// silently dropped).
Future<List<TrackedMovementCount>?> showMovementCountDialog(
  BuildContext context, {
  required List<TrackedMovementCount> defaultCounts,
}) {
  return showDialog<List<TrackedMovementCount>>(
    context: context,
    builder: (_) => _MovementCountDialog(defaultCounts: defaultCounts),
  );
}

class _MovementCountDialog extends StatefulWidget {
  const _MovementCountDialog({required this.defaultCounts});
  final List<TrackedMovementCount> defaultCounts;

  @override
  State<_MovementCountDialog> createState() => _MovementCountDialogState();
}

class _MovementCountDialogState extends State<_MovementCountDialog> {
  late List<TrackedMovementCount> _counts;

  @override
  void initState() {
    super.initState();
    _counts = List.of(widget.defaultCounts);
  }

  void _adjust(int index, int delta) {
    setState(() {
      final next = (_counts[index].count + delta).clamp(0, 9999);
      _counts[index] = _counts[index].copyWith(count: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('How many did you do?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _counts.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(_counts[i].displayName)),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _adjust(i, -1),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text('${_counts[i].count}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _adjust(i, 1),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: cs.primary),
          onPressed: () => Navigator.pop(context, _counts),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
