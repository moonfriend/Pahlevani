import 'package:just_audio/just_audio.dart';

/// What just_audio plays for an [AudioPlayerService] queue: one path as a
/// plain source; several as one concatenated source, so the next recording
/// is preloaded and starts without a gap. Shared by the native and the web
/// engine.
AudioSource queueSource(List<String> paths) {
  if (paths.length == 1) return _sourceFor(paths.single);
  return ConcatenatingAudioSource(
      children: [for (final path in paths) _sourceFor(path)]);
}

/// Looping repeats a single path by itself, and a longer queue from its
/// first path once the last one ends.
LoopMode queueLoopMode({required int pathCount, required bool looping}) {
  if (!looping) return LoopMode.off;
  return pathCount > 1 ? LoopMode.all : LoopMode.one;
}

/// Loads [paths] into [player] with the matching loop mode.
Future<void> loadQueue(AudioPlayer player, List<String> paths,
    {required bool looping}) async {
  if (paths.isEmpty) throw ArgumentError.value(paths, 'paths', 'is empty');
  await player
      .setLoopMode(queueLoopMode(pathCount: paths.length, looping: looping));
  await player.setAudioSource(queueSource(paths));
}

bool isRemoteUrl(String path) =>
    path.startsWith('http://') || path.startsWith('https://');

UriAudioSource _sourceFor(String path) => isRemoteUrl(path)
    ? AudioSource.uri(Uri.parse(path))
    : AudioSource.file(path);
