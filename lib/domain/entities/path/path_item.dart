/// One checklist entry on a [PathNode] — a training session (done
/// [SessionPathItem.repeatCount] times), a video, or a quote. `id` is the
/// real `path_node_item.id` and is what local progress tracking keys off.
sealed class PathItem {
  const PathItem();

  int get id;
}

class SessionPathItem extends PathItem {
  @override
  final int id;
  final int trainingSessionId;
  final int repeatCount;

  const SessionPathItem({
    required this.id,
    required this.trainingSessionId,
    required this.repeatCount,
  });
}

class VideoPathItem extends PathItem {
  @override
  final int id;
  final String url;
  final String? title;

  const VideoPathItem({required this.id, required this.url, this.title});
}

class QuotePathItem extends PathItem {
  @override
  final int id;
  final String text;
  final String? author;

  const QuotePathItem({required this.id, required this.text, this.author});
}
