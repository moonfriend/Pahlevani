/// Plain view-model types for the Trainee Home / Trainer Page static
/// preview. These are intentionally NOT domain entities — Track 1 of the
/// home redesign is visual-only (no Cubit/repository wiring yet). Shape
/// mirrors the design handoff's "State Management" section so wiring real
/// data in later tracks is a straight swap.
library;

enum SectionKey { narmesh, sheno, meel, sang, pa }

enum SectionStatus { done, inProgress, notStarted }

class TraineeProfile {
  const TraineeProfile({
    required this.name,
    required this.rank,
    required this.houseNameFarsi,
    required this.houseNameEnglish,
    required this.houseProgressPercent,
    required this.nextHouseName,
  });

  final String name;
  final String rank;
  final String houseNameFarsi;
  final String houseNameEnglish;
  final int houseProgressPercent;
  final String nextHouseName;
}

class SectionSummary {
  const SectionSummary({
    required this.key,
    required this.name,
    required this.subtitle,
    required this.moveCount,
    required this.status,
    this.doneCount,
  });

  final SectionKey key;
  final String name;
  final String subtitle;
  final int moveCount;
  final SectionStatus status;

  /// Only meaningful when [status] is [SectionStatus.inProgress].
  final int? doneCount;
}

class LearnModuleSummary {
  const LearnModuleSummary({
    required this.name,
    required this.unlocked,
    this.lessonsLabel,
    this.unlockCondition,
  });

  final String name;
  final bool unlocked;
  final String? lessonsLabel;
  final String? unlockCondition;
}

class StudentSummary {
  const StudentSummary({
    required this.name,
    required this.rank,
    required this.houseLabel,
    required this.progressPercent,
  });

  final String name;
  final String rank;
  final String houseLabel;
  final int progressPercent;
}

class TrainerStat {
  const TrainerStat({
    required this.value,
    required this.label,
    required this.variant,
  });

  final String value;
  final String label;
  final TrainerStatVariant variant;
}

enum TrainerStatVariant { teal, plain, amber }

class SubMoveSummary {
  const SubMoveSummary({
    required this.index,
    required this.name,
    required this.variant,
    required this.sets,
    required this.reps,
  });

  final int index;
  final String name;
  final String variant;
  final int sets;
  final int reps;
}

class BuildSection {
  const BuildSection({
    required this.key,
    required this.name,
    required this.moveCount,
    this.focus = false,
    this.subMoves,
  });

  final SectionKey key;
  final String name;
  final int moveCount;
  final bool focus;

  /// Non-null only for the single expanded section.
  final List<SubMoveSummary>? subMoves;

  bool get isExpanded => subMoves != null;
}

class LearningToggle {
  const LearningToggle({required this.name, required this.enabled});

  final String name;
  final bool enabled;
}

/// Canned sample data matching the design mockup, for side-by-side review.
class HomePreviewData {
  HomePreviewData._();

  static const trainee = TraineeProfile(
    name: 'Reza Ahmadi',
    rank: 'Nowkhaste',
    houseNameFarsi: 'KHÂNE-YE AVVAL',
    houseNameEnglish: 'FIRST HOUSE',
    houseProgressPercent: 35,
    nextHouseName: 'Khâne-ye Dovvom',
  );

  static const todaysSections = <SectionSummary>[
    SectionSummary(
      key: SectionKey.narmesh,
      name: 'Narmesh',
      subtitle: '3 moves · warm-up',
      moveCount: 3,
      status: SectionStatus.done,
    ),
    SectionSummary(
      key: SectionKey.sheno,
      name: 'Sheno',
      subtitle: '6 moves · push-ups',
      moveCount: 6,
      status: SectionStatus.inProgress,
      doneCount: 4,
    ),
    SectionSummary(
      key: SectionKey.meel,
      name: 'Meel',
      subtitle: '4 moves · clubs',
      moveCount: 4,
      status: SectionStatus.notStarted,
    ),
    SectionSummary(
      key: SectionKey.sang,
      name: 'Sang',
      subtitle: '2 moves · shield',
      moveCount: 2,
      status: SectionStatus.notStarted,
    ),
    SectionSummary(
      key: SectionKey.pa,
      name: 'Pâ',
      subtitle: '3 moves · footwork',
      moveCount: 3,
      status: SectionStatus.notStarted,
    ),
  ];

  static const learnModules = <LearnModuleSummary>[
    LearnModuleSummary(
        name: 'Learn correct Meel',
        unlocked: true,
        lessonsLabel: '3 short lessons'),
    LearnModuleSummary(
        name: 'Learn correct Sheno',
        unlocked: true,
        lessonsLabel: '2 short lessons'),
    LearnModuleSummary(
        name: 'Learn correct Sang',
        unlocked: false,
        unlockCondition: 'Unlocks at 60%'),
    LearnModuleSummary(
        name: 'Learn the Charkh (whirl)',
        unlocked: false,
        unlockCondition: 'Second house'),
  ];

  static const student = StudentSummary(
    name: 'Reza Ahmadi',
    rank: 'Nowkhaste',
    houseLabel: 'first house',
    progressPercent: 35,
  );

  static const trainerStats = <TrainerStat>[
    TrainerStat(
        value: '12', label: 'day streak', variant: TrainerStatVariant.teal),
    TrainerStat(
        value: '2/5', label: 'today done', variant: TrainerStatVariant.plain),
    TrainerStat(
        value: 'Sang', label: 'weak spot', variant: TrainerStatVariant.amber),
  ];

  static const buildSections = <BuildSection>[
    BuildSection(
      key: SectionKey.sheno,
      name: 'Sheno',
      moveCount: 6,
      subMoves: [
        SubMoveSummary(
            index: 1, name: 'Sineh', variant: 'chest', sets: 3, reps: 12),
        SubMoveSummary(
            index: 2, name: 'Sarsineh', variant: 'upper', sets: 3, reps: 10),
        SubMoveSummary(
            index: 3, name: 'Jeng', variant: 'one-arm', sets: 2, reps: 8),
        SubMoveSummary(
            index: 4, name: 'Parsi', variant: 'wide', sets: 2, reps: 15),
        SubMoveSummary(
            index: 5, name: 'Charkhi', variant: 'rotating', sets: 2, reps: 10),
        SubMoveSummary(
            index: 6, name: 'Pā-boland', variant: 'feet-up', sets: 1, reps: 12),
      ],
    ),
    BuildSection(key: SectionKey.narmesh, name: 'Narmesh', moveCount: 3),
    BuildSection(key: SectionKey.meel, name: 'Meel', moveCount: 4),
    BuildSection(key: SectionKey.sang, name: 'Sang', moveCount: 2, focus: true),
    BuildSection(key: SectionKey.pa, name: 'Pâ', moveCount: 3),
  ];

  static const learningToggles = <LearningToggle>[
    LearningToggle(name: 'Correct Meel', enabled: true),
    LearningToggle(name: 'Correct Sheno', enabled: true),
    LearningToggle(name: 'Correct Sang', enabled: false),
    LearningToggle(name: 'The Charkh (whirl)', enabled: false),
  ];
}
