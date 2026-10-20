class PathNodeItemRow {
  final int id;
  final int pathNodeId;
  final int position;
  final String itemType; // 'session' | 'video' | 'quote'
  final int? trainingSessionId;
  final int repeatCount;
  final String? videoUrl;
  final String? videoTitle;
  final String? quoteText;
  final String? quoteAuthor;

  PathNodeItemRow({
    required this.id,
    required this.pathNodeId,
    required this.position,
    required this.itemType,
    this.trainingSessionId,
    required this.repeatCount,
    this.videoUrl,
    this.videoTitle,
    this.quoteText,
    this.quoteAuthor,
  });

  factory PathNodeItemRow.fromJson(Map<String, dynamic> json) =>
      PathNodeItemRow(
        id: (json['id'] as num).toInt(),
        pathNodeId: (json['path_node_id'] as num).toInt(),
        position: (json['position'] as num).toInt(),
        itemType: json['item_type'] as String,
        trainingSessionId: (json['training_session_id'] as num?)?.toInt(),
        repeatCount: (json['repeat_count'] as num?)?.toInt() ?? 1,
        videoUrl: json['video_url'] as String?,
        videoTitle: json['video_title'] as String?,
        quoteText: json['quote_text'] as String?,
        quoteAuthor: json['quote_author'] as String?,
      );
}
