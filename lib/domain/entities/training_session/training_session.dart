class TrainingSession {
  final int id;
  final String title;
  final String? titleFa;
  final String description;
  final int difficulty;
  final DateTime? createdAt;
  final bool isUserCreated;

  /// Public catalog session (default) vs. an individualized one a trainer
  /// built for a specific trainee. Existing/public sessions are unaffected —
  /// this defaults to true everywhere.
  final bool isPublic;

  /// Set together: the trainee this session was assigned to, and the
  /// trainer who assigned it. Both null for public catalog sessions.
  final String? assignedToUserId;
  final String? assignedByTrainerId;

  bool get isIndividualized => assignedToUserId != null;

  TrainingSession({
    required this.id,
    required this.title,
    this.titleFa,
    required this.description,
    required this.difficulty,
    this.createdAt,
    this.isUserCreated = false,
    this.isPublic = true,
    this.assignedToUserId,
    this.assignedByTrainerId,
  });

  TrainingSession copyWith({
    int? id,
    String? title,
    String? titleFa,
    String? description,
    int? difficulty,
    DateTime? createdAt,
    bool? isUserCreated,
    bool? isPublic,
    String? assignedToUserId,
    String? assignedByTrainerId,
  }) {
    return TrainingSession(
      id: id ?? this.id,
      title: title ?? this.title,
      titleFa: titleFa ?? this.titleFa,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
      isUserCreated: isUserCreated ?? this.isUserCreated,
      isPublic: isPublic ?? this.isPublic,
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      assignedByTrainerId: assignedByTrainerId ?? this.assignedByTrainerId,
    );
  }
}
