import 'package:flutter/material.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_type.dart';

/// Shown right after a session finishes, when it contained at least one
/// tracked movement type. Prefilled with the programmed total for each type
/// present; the user can adjust before saving. Returns the edited counts, or
/// null if dismissed without an explicit Save (callers should fall back to
/// the prefilled defaults in that case, so a session's totals are never
/// silently dropped).
Future<Map<TrackedMovementType, int>?> showMovementCountDialog(
  BuildContext context, {
  required Map<TrackedMovementType, int> defaultCounts,
}) {
  return showDialog<Map<TrackedMovementType, int>>(
    context: context,
    builder: (_) => _MovementCountDialog(defaultCounts: defaultCounts),
  );
}

class _MovementCountDialog extends StatefulWidget {
  const _MovementCountDialog({required this.defaultCounts});
  final Map<TrackedMovementType, int> defaultCounts;

  @override
  State<_MovementCountDialog> createState() => _MovementCountDialogState();
}

class _MovementCountDialogState extends State<_MovementCountDialog> {
  late Map<TrackedMovementType, int> _counts;

  @override
  void initState() {
    super.initState();
    _counts = Map.of(widget.defaultCounts);
  }

  void _adjust(TrackedMovementType type, int delta) {
    setState(() {
      final next = (_counts[type] ?? 0) + delta;
      _counts[type] = next.clamp(0, 9999);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final types = widget.defaultCounts.keys.toList();

    return AlertDialog(
      title: const Text('How many did you do?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final type in types)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(type.displayName,
                        textDirection: TextDirection.rtl),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _adjust(type, -1),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text('${_counts[type] ?? 0}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _adjust(type, 1),
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
