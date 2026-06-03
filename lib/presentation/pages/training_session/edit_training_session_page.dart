import 'package:flutter/material.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

class EditTrainingSessionPage extends StatefulWidget {
  final TrainingSession trainingSession;
  final List<ItemDetail> items; // ordered items from SessionDetail

  const EditTrainingSessionPage({
    super.key,
    required this.trainingSession,
    required this.items,
  });

  @override
  State<EditTrainingSessionPage> createState() => _EditTrainingSessionPageState();
}

class _EditTrainingSessionPageState extends State<EditTrainingSessionPage> {
  late List<ItemDetail> _items;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _hasChanges = false;

  // exerciseId → repetition count (user-editable, initialised from prescription)
  late Map<int, int> _repetitionsMap;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
    _titleController = TextEditingController(text: widget.trainingSession.title);
    _descriptionController = TextEditingController(text: widget.trainingSession.description);
    _repetitionsMap = {
      for (final item in _items)
        item.item.exerciseId: item.item.prescription is RepsPresc
            ? (item.item.prescription as RepsPresc).count
            : 1,
    };
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _removeItem(int index) {
    setState(() {
      _repetitionsMap.remove(_items[index].item.exerciseId);
      _items.removeAt(index);
      _hasChanges = true;
    });
  }

  void _reorderItems(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      _hasChanges = true;
    });
  }

  void _saveChanges() {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }
    // Returns the updated session metadata + ordered items with new rep counts
    // so the calling page can persist via the cubit.
    // Items are re-indexed by position = their current list index.
    Navigator.pop(context, {
      'session': widget.trainingSession.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        isUserCreated: true,
      ),
      'items': _items,
      'repetitionsMap': _repetitionsMap,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Edit ${widget.trainingSession.title}',
          style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        backgroundColor: theme.colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded, size: 28),
            tooltip: 'Save',
            onPressed: _saveChanges,
          ),
        ],
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  style: theme.textTheme.titleMedium,
                  decoration: InputDecoration(
                    labelText: 'Session Title',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: theme.cardColor,
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                  onChanged: (_) => setState(() => _hasChanges = true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: theme.cardColor,
                    prefixIcon: const Icon(Icons.description_rounded),
                  ),
                  maxLines: 2,
                  onChanged: (_) => setState(() => _hasChanges = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Text(
                      'No exercises in this session.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ReorderableListView.builder(
                      itemCount: _items.length,
                      onReorder: _reorderItems,
                      buildDefaultDragHandles: false,
                      itemBuilder: (context, index) {
                        final detail = _items[index];
                        final exerciseId = detail.item.exerciseId;
                        final reps = _repetitionsMap[exerciseId] ?? 1;
                        return Card(
                          key: ValueKey(exerciseId),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        top: 8.0, right: 8),
                                    child: Icon(
                                      Icons.drag_indicator_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 28,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        detail.exercise.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                      if (detail.exercise.author != null)
                                        Text(
                                          detail.exercise.author!,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                  color: theme.hintColor),
                                        ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary
                                                  .withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                const Text('Repetitions:',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500)),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons
                                                          .remove_circle_outline,
                                                      size: 22),
                                                  splashRadius: 18,
                                                  onPressed: reps > 1
                                                      ? () => setState(() {
                                                            _repetitionsMap[
                                                                    exerciseId] =
                                                                reps - 1;
                                                            _hasChanges = true;
                                                          })
                                                      : null,
                                                ),
                                                Text('$reps',
                                                    style: theme
                                                        .textTheme.titleMedium),
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.add_circle_outline,
                                                      size: 22),
                                                  splashRadius: 18,
                                                  onPressed: () =>
                                                      setState(() {
                                                    _repetitionsMap[
                                                        exerciseId] = reps + 1;
                                                    _hasChanges = true;
                                                  }),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_forever_rounded,
                                      color: Colors.redAccent,
                                      size: 28),
                                  tooltip: 'Remove exercise',
                                  onPressed: () => _removeItem(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
