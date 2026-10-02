import '../../../core/theme/kashi/kashi_assets.dart';

// PLACEHOLDER DATA — the moves catalog the Library and learning card need
// (steps, Lighter/Harder variations, cues, Farsi names) doesn't exist in
// the data model yet (see the Kashi redesign plan, "Data the design needs").
// These are the handoff prototype's sample moves so the screens can be built
// and reviewed now; replace with a real catalog when it lands.

/// A Lighter/Harder step of a move.
class MoveVariation {
  const MoveVariation({
    required this.name,
    required this.level,
    required this.reps,
  });

  final String name;

  /// e.g. "EASIER · 4 KG".
  final String level;
  final int reps;
}

/// A move as the Library and learning card show it.
class SampleMove {
  const SampleMove({
    required this.id,
    required this.name,
    required this.nameFa,
    required this.minutes,
    required this.description,
    required this.image,
    this.target,
    this.steps = const [],
    this.variations = const [],
  });

  final String id;
  final String name;
  final String nameFa;
  final int minutes;
  final String description;
  final String image;

  /// Rep target when a trainer flagged this move for counting.
  final int? target;
  final List<String> steps;

  /// Ordered lightest → hardest; the middle one is the standard move.
  final List<MoveVariation> variations;

  bool get isTracked => target != null;
}

const List<SampleMove> sampleMoves = [
  SampleMove(
    id: 'vorod',
    name: 'Vorod',
    nameFa: 'ورود',
    minutes: 5,
    image: KashiAssets.pahlevanMale,
    description: 'Entering the gowd. A bow to the morshed and the circle '
        'before the work begins.',
  ),
  SampleMove(
    id: 'shena',
    name: 'Shena',
    nameFa: 'شنا',
    minutes: 12,
    target: 40,
    image: KashiAssets.pahlevanFemale,
    description: 'A wave-like press on the board. The body sweeps low and '
        'forward, one rep per beat of the zarb.',
    steps: [
      'Hands wide on the board, hips high.',
      'Sweep the chest forward and low, like a wave.',
      'Push back to the start, one rep per beat.',
    ],
    variations: [
      MoveVariation(name: 'Knee Shena', level: 'EASIER', reps: 25),
      MoveVariation(name: 'Shena', level: 'STANDARD', reps: 40),
      MoveVariation(name: 'Sar Navazi', level: 'HARDER', reps: 60),
    ],
  ),
  SampleMove(
    id: 'pa',
    name: 'Pa Zadan',
    nameFa: 'پا زدن',
    minutes: 10,
    image: KashiAssets.pahlevanMale,
    description: 'Rhythmic stepping in place, knees high, keeping time with '
        'the morshed.',
  ),
  SampleMove(
    id: 'meel',
    name: 'Meel Giri',
    nameFa: 'میل‌گیری',
    minutes: 15,
    target: 50,
    image: KashiAssets.pahlevanFemale,
    description: 'Swinging the meels behind the back and over the shoulders, '
        'alternating sides on the beat.',
    steps: [
      'Hold the meel upright by your shoulder, elbow tucked.',
      'Let it fall behind the back and circle round the head.',
      'Return upright on the beat and switch sides.',
    ],
    variations: [
      MoveVariation(name: 'Light meels', level: 'EASIER · 4 KG', reps: 30),
      MoveVariation(name: 'Meel Giri', level: 'STANDARD · 6 KG', reps: 50),
      MoveVariation(name: 'Heavy meels', level: 'HARDER · 8 KG', reps: 50),
    ],
  ),
  SampleMove(
    id: 'charkh',
    name: 'Charkh',
    nameFa: 'چرخ',
    minutes: 8,
    image: KashiAssets.pahlevanMale,
    description: 'Spinning in place with arms open. Speed builds with the '
        'zarb.',
  ),
  SampleMove(
    id: 'sang',
    name: 'Sang',
    nameFa: 'سنگ',
    minutes: 14,
    image: KashiAssets.pahlevanFemale,
    description: 'Lying on the back, raising the wooden sang shields in turn.',
  ),
  SampleMove(
    id: 'doa',
    name: 'Doa',
    nameFa: 'دعا',
    minutes: 7,
    image: KashiAssets.pahlevanMale,
    description: 'The closing prayer, standing together in the circle.',
  ),
];
