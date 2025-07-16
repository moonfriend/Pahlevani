import 'package:flutter/material.dart';
import 'package:pahlevani/domain/entities/playlist/playlist.dart';
import 'package:pahlevani/domain/entities/playlist/audio.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/data/datasources/playlist/playlist_local_database.dart';
import 'package:pahlevani/data/models/hive_models.dart';

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
    _repetitionsMap = { for (final song in _songs) song.id: 1 };
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.playlist.title}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Playlist Title',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _hasChanges = true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onChanged: (value) => setState(() => _hasChanges = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _songs.length,
              onReorder: _reorderSongs,
              itemBuilder: (context, index) {
                final song = _songs[index];
                return ListTile(
                  key: ValueKey(song.id),
                  leading: const Icon(Icons.drag_handle),
                  title: Text(song.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.author),
                      Row(
                        children: [
                          const Text('Repetitions: '),
                          IconButton(
                            icon: const Icon(Icons.remove),
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
                          Text('${_repetitionsMap[song.id] ?? 1}'),
                          IconButton(
                            icon: const Icon(Icons.add),
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
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeSong(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 