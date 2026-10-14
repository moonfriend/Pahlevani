class TrainingSession {
  final int id;
  final String title;
  final String? titleFa;
  final String description;
  final int difficulty;
  final DateTime? createdAt;
  final bool isUserCreated;

  /// Public catalog session (default) vs. one a trainer authored privately.
  /// Existing/public sessions are unaffected — this defaults to true
  /// everywhere.
  final bool isPublic;

  /// The trainer who authored this private session, if any (null for public
  /// catalog sessions). Deliberately not paired with a single assignee —
  /// who it's assigned to lives in SessionAssignment, since one session can
  /// be assigned to any number of trainees.
  final String? ownerTrainerId;

  /// Home's slot for this session (admin-set): 1 = the main card, 2 and
  /// 3 = the small cards; null = not on Home.
  final int? homePosition;

  /// The session uses meel; Home tags it for people without meel yet.
  final bool needsMeel;

  TrainingSession({
    required this.id,
    required this.title,
    this.titleFa,
    required this.description,
    required this.difficulty,
    this.createdAt,
    this.isUserCreated = false,
    this.isPublic = true,
    this.ownerTrainerId,
    this.homePosition,
    this.needsMeel = false,
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
    String? ownerTrainerId,
    int? homePosition,
    bool? needsMeel,
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
      ownerTrainerId: ownerTrainerId ?? this.ownerTrainerId,
      homePosition: homePosition ?? this.homePosition,
      needsMeel: needsMeel ?? this.needsMeel,
    );
  }
}
