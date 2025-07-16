import 'package:flutter/material.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/data/datasources/playlist/playlist_local_database.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/domain/entities/playlist/audio.dart';
import 'package:pahlevani/domain/entities/playlist/playlist.dart';

class EditPlaylistPage extends StatefulWidget {
  final Playlist playlist;

  const EditPlaylistPage({
    super.key,
    required this.playlist,
  });

  @override
  State<EditPlaylistPage> createState() => _EditPlaylistPageState();
}

class _EditPlaylistPageState extends State<EditPlaylistPage> {
  late List<Audio> _songs;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _hasChanges = false;

  // Map from songId to repetitions
  late Map<int, int> _repetitionsMap;

  @override
  void initState() {
    super.initState();
    _songs = List.from(widget.playlist.songs);
    _titleController = TextEditingController(text: widget.playlist.title);
    _descriptionController = TextEditingController(text: widget.playlist.description);
    _repetitionsMap = {for (final song in _songs) song.id: 1};
    _loadRepetitionsFromLocal();
  }

  Future<void> _loadRepetitionsFromLocal() async {
    final db = getIt<PlaylistLocalDatabase>();
    final playlistSongs = await db.getPlaylistSongs();
    final currentPlaylistSongs = playlistSongs.where((ps) => ps.playlistId == widget.playlist.id).toList();
    final map = <int, int>{};
    for (final song in _songs) {
      HivePlaylistSong? ps;
      try {
        ps = currentPlaylistSongs.firstWhere((p) => p.songId == song.id);
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
      _repetitionsMap.remove(_songs[index].id);
      _songs.removeAt(index);
      _hasChanges = true;
    });
  }

  void _reorderSongs(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final song = _songs.removeAt(oldIndex);
      _songs.insert(newIndex, song);
      // Repetitions map remains valid since song ids are unchanged
      _hasChanges = true;
    });
  }

  void _saveChanges() {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    final isEditingUserPlaylist = widget.playlist.isUserCreated;
    final newId = isEditingUserPlaylist ? widget.playlist.id : DateTime.now().millisecondsSinceEpoch;
    final updatedPlaylist = Playlist(
      id: newId,
      title: _titleController.text,
      description: _descriptionController.text,
      difficulty: widget.playlist.difficulty,
      createdAt: DateTime.now(),
      songs: _songs.map((song) {
        return Audio(
          id: song.id,
          name: song.name,
          author: song.author,
          type: song.type,
          url: song.url,
          position: song.position,
        );
      }).toList(),
      isUserCreated: true, // Always mark as user-created for edits
    );

    // Pass repetitions map as a second argument
    Navigator.pop(context, {
      'playlist': updatedPlaylist,
      'repetitionsMap': _repetitionsMap,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background.withOpacity(0.98),
      appBar: AppBar(
        title: Text('Edit ${widget.playlist.title}', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
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
                    labelText: 'Playlist Title',
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
                itemCount: _songs.length,
                onReorder: _reorderSongs,
                buildDefaultDragHandles: false,
                itemBuilder: (context, index) {
                  final song = _songs[index];
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
