class TrainingSessionRow {
  final int id;
  final String? title;
  final String? titleFa;
  final String? description;
  final int? difficulty;
  final DateTime? createdAt;
  final bool? isUserCreated;
  final String? assignedToUserId;
  final String? assignedByTrainerId;

  TrainingSessionRow({
    required this.id,
    this.title,
    this.titleFa,
    this.description,
    this.difficulty,
    this.createdAt,
    this.isUserCreated,
    this.assignedToUserId,
    this.assignedByTrainerId,
  });

  factory TrainingSessionRow.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['created_at'] is String) {
      parsedDate = DateTime.tryParse(json['created_at'] as String);
    }
    return TrainingSessionRow(
      id: json['id'] as int? ?? 1,
      title: json['title'] as String? ?? 'Unknown TrainingSession',
      titleFa: json['title_fa'] as String?,
      description: json['description'] as String? ?? '',
      difficulty: json['difficulty'] as int? ?? 1,
      createdAt: parsedDate,
      isUserCreated: json['is_user_created'] as bool? ?? false,
      assignedToUserId: json['assigned_to_user_id'] as String?,
      assignedByTrainerId: json['assigned_by_trainer_id'] as String?,
    );
  }
}
