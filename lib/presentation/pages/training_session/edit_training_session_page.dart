import 'package:flutter/material.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_database.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

class EditTrainingSessionPage extends StatefulWidget {
  final TrainingSession training_session;

  const EditTrainingSessionPage({
    super.key,
    required this.training_session,
  });

  @override
  State<EditTrainingSessionPage> createState() => _EditTrainingSessionPageState();
}

class _EditTrainingSessionPageState extends State<EditTrainingSessionPage> {
  late List<TrainingSessionItem> _items;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _hasChanges = false;

  // Map from songId to repetitions
  late Map<int, int> _repetitionsMap;

  @override
  void initState() {
    super.initState();
    _items = []; // items are loaded separately via DomainSnapshot, not embedded in TrainingSession
    _titleController = TextEditingController(text: widget.training_session.title);
    _descriptionController = TextEditingController(text: widget.training_session.description);
    _repetitionsMap = {for (final song in _items) song.id: 1};
    _loadRepetitionsFromLocal();
  }

  Future<void> _loadRepetitionsFromLocal() async {
    final db = getIt<TrainingSessionLocalDatabase>();
    final training_sessionSongs = await db.getTrainingSessionItems();
    final currentTrainingSessionSongs = training_sessionSongs.where((ps) => ps.trainingSessionId == widget.training_session.id).toList();
    final map = <int, int>{};
    for (final song in _items) {
      HiveTrainingSessionItem? ps;
      try {
        ps = currentTrainingSessionSongs.firstWhere((p) => p.itemId == song.id);
      } catch (_) {
        ps = null;
      }
      map[song.id] = ps?.repsToDo ?? 1;
    }
    setState(() {
      _repetitionsMap = map;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _removeSong(int index) {
    setState(() {
      _repetitionsMap.remove(_items[index].id);
      _items.removeAt(index);
      _hasChanges = true;
    });
  }

  void _reorderSongs(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final song = _items.removeAt(oldIndex);
      _items.insert(newIndex, song);
      // Repetitions map remains valid since song ids are unchanged
      _hasChanges = true;
    });
  }

  void _saveChanges() {
    print("Saving changes - hasChanges: $_hasChanges");
    print("Original title: ${widget.training_session.title}, New title: ${_titleController.text}");
    print("Original description: ${widget.training_session.description}, New description: ${_descriptionController.text}");
    print("New songs count: ${_items.length}");
    //
    // if (!_hasChanges) {
    //   print("No changes detected, just popping");
    //   Navigator.pop(context);
    //   return;
    // }
    //
    // final isEditingUserTrainingSession = widget.training_session.isUserCreated;
    // final newId = isEditingUserTrainingSession ? widget.training_session.id : DateTime.now().millisecondsSinceEpoch;
    // final updatedTrainingSession = TrainingSession(
    //   id: newId,
    //   title: _titleController.text,
    //   description: _descriptionController.text,
    //   difficulty: widget.training_session.difficulty,
    //   createdAt: DateTime.now(),
    //   items: _items.map((song) {
    //     return TrainingSessionItem(
    //       id: song.id,
    //       name: song.name,
    //       author: song.author,
    //       type: song.type,
    //       audioFileUrl: song.audioFileUrl,
    //       position: song.position,
    //       repsToDo: song.repsToDo,//TODO: this was added to skip error, double check
    //     );
    //   }).toList(),
    //   isUserCreated: true, // Always mark as user-created for edits
    // );
    //
    // print("Returning updated training_session with ID: ${updatedTrainingSession.id}, isUserCreated: ${updatedTrainingSession.isUserCreated}");
    // print("Repetitions map: $_repetitionsMap");
    //
    // // Pass repetitions map as a second argument
    // Navigator.pop(context, {
    //   'training_session': updatedTrainingSession,
    //   'repetitionsMap': _repetitionsMap,
    // });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background.withOpacity(0.98),
      appBar: AppBar(
        title: Text('Edit ${widget.training_session.title}', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
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
                    labelText: 'TrainingSession Title',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: theme.cardColor,
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                  onChanged: (value) => setState(() => _hasChanges = true),
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
                  onChanged: (value) => setState(() => _hasChanges = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ReorderableListView.builder(
                itemCount: _items.length,
                onReorder: _reorderSongs,
                buildDefaultDragHandles: false,
                itemBuilder: (context, index) {
                  final song = _items[index];
                  return Card(
                    key: ValueKey(song.id),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8.0, right: 8),
                              child: Icon(Icons.drag_indicator_rounded, color: theme.colorScheme.primary, size: 28),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(song.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(song.author, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Text('Repetitions:', style: TextStyle(fontWeight: FontWeight.w500)),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, size: 22),
                                            splashRadius: 18,
                                            onPressed: () {
                                              setState(() {
                                                final current = _repetitionsMap[song.id] ?? 1;
                                                if (current > 1) {
                                                  _repetitionsMap[song.id] = current - 1;
                                                  _hasChanges = true;
                                                }
                                              });
                                            },
                                          ),
                                          Text('${_repetitionsMap[song.id] ?? 1}', style: theme.textTheme.titleMedium),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, size: 22),
                                            splashRadius: 18,
                                            onPressed: () {
                                              setState(() {
                                                final current = _repetitionsMap[song.id] ?? 1;
                                                _repetitionsMap[song.id] = current + 1;
                                                _hasChanges = true;
                                              });
                                            },
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
                            icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 28),
                            tooltip: 'Remove song',
                            onPressed: () => _removeSong(index),
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
