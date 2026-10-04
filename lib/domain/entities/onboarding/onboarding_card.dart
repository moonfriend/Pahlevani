import 'package:equatable/equatable.dart';

/// Pictures bundled in the app — a card falls back to one when it has no
/// uploaded image, or the image can't load (offline first open).
enum BuiltinOnboardingImage {
  /// The figure picked for this session.
  figure,

  /// The other figure.
  figureAlt,

  /// A shamseh rosette.
  shamseh,
}

/// One first-open onboarding card. Edited in the admin panel (table
/// `onboarding_cards`), so cards change without an app update.
class OnboardingCard extends Equatable {
  const OnboardingCard({
    required this.title,
    required this.body,
    this.imageUrl,
    this.builtinImage = BuiltinOnboardingImage.figure,
  });

  final String title;
  final String body;

  /// Uploaded picture; wins over [builtinImage] when it loads.
  final String? imageUrl;
  final BuiltinOnboardingImage builtinImage;

  @override
  List<Object?> get props => [title, body, imageUrl, builtinImage];
}

/// Shown until the server's cards have been fetched once, and whenever the
/// server has no active cards. Same copy as the migration's seed rows.
const List<OnboardingCard> defaultOnboardingCards = [
  OnboardingCard(
    title: 'Train with your morshed',
    body: 'Each session is a video led by the morshed’s voice and the beat '
        'of the zarb.',
  ),
  OnboardingCard(
    title: 'Count what matters',
    body: 'Your trainers mark the moves worth counting. Log your reps as you '
        'go.',
    builtinImage: BuiltinOnboardingImage.figureAlt,
  ),
  OnboardingCard(
    title: 'Lay a tile every session',
    body: 'Your shamseh grows ring by ring. It never resets, so a missed week '
        'costs you nothing.',
    builtinImage: BuiltinOnboardingImage.shamseh,
  ),
];
