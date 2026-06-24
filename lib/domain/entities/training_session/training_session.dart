class TrainingSession {
  final int id;
  final String title;
  final String? titleFa;
  final String description;
  final int difficulty;
  final DateTime? createdAt;
  final bool isUserCreated;

  /// Null = an "original training" — public, visible to every signed-in
  /// user. Set = an individualized session, visible only to this trainee
  /// (enforced server-side by RLS once the auth migration is applied).
  final String? assignedToUserId;

  /// Which trainer built this individualized session — null for original
  /// trainings. Lets a trainer's app list "sessions I assigned" via this
  /// column without needing a separate query parameter.
  final String? assignedByTrainerId;

  TrainingSession({
    required this.id,
    required this.title,
    this.titleFa,
    required this.description,
    required this.difficulty,
    this.createdAt,
    this.isUserCreated = false,
    this.assignedToUserId,
    this.assignedByTrainerId,
  });

  bool get isIndividualized => assignedToUserId != null;

  TrainingSession copyWith({
    int? id,
    String? title,
    String? titleFa,
    String? description,
    int? difficulty,
    DateTime? createdAt,
    bool? isUserCreated,
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
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      assignedByTrainerId: assignedByTrainerId ?? this.assignedByTrainerId,
    );
  }
}
