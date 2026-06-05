class TrainingSession {
  final int id;
  final String title;
  final String? titleFa;
  final String description;
  final int difficulty;
  final DateTime? createdAt;
  final bool isUserCreated;

  TrainingSession({
    required this.id,
    required this.title,
    this.titleFa,
    required this.description,
    required this.difficulty,
    this.createdAt,
    this.isUserCreated = false,
  });

  TrainingSession copyWith({
    int? id,
    String? title,
    String? titleFa,
    String? description,
    int? difficulty,
    DateTime? createdAt,
    bool? isUserCreated,
  }) {
    return TrainingSession(
      id: id ?? this.id,
      title: title ?? this.title,
      titleFa: titleFa ?? this.titleFa,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
      isUserCreated: isUserCreated ?? this.isUserCreated,
    );
  }
}
