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

/// A button under a card's text, opening a page on our website (e.g. the
/// meel card's "Order").
class OnboardingLink extends Equatable {
  const OnboardingLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  List<Object?> get props => [label, url];
}

/// One first-open onboarding card. Edited in the admin panel (table
/// `onboarding_cards`), so cards change without an app update.
class OnboardingCard extends Equatable {
  const OnboardingCard({
    required this.title,
    required this.body,
    this.imageUrl,
    this.builtinImage = BuiltinOnboardingImage.figure,
    this.links = const [],
  });

  final String title;
  final String body;

  /// Uploaded picture; wins over [builtinImage] when it loads.
  final String? imageUrl;
  final BuiltinOnboardingImage builtinImage;

  /// Up to three buttons under the text (migration 0046).
  final List<OnboardingLink> links;

  @override
  List<Object?> get props => [title, body, imageUrl, builtinImage, links];
}

/// Shown until the server's cards have been fetched once, and whenever the
/// server has no active cards. Same copy as release 1's cards on the server
/// (the meel card's buttons live only on the server).
const List<OnboardingCard> defaultOnboardingCards = [
  OnboardingCard(
    title: 'The Zoorkhaneh in your pocket',
    body: 'Pahlevani is the old Persian practice of strength and chivalry, '
        'trained to the drum and voice of a morshed.',
  ),
  OnboardingCard(
    title: 'A morshed leads, you follow',
    body: 'Pick a session and press Start. Follow the morshed’s count, '
        'and learn each move from its card on the way. Every session you '
        'finish marks your calendar.',
    builtinImage: BuiltinOnboardingImage.figureAlt,
  ),
  OnboardingCard(
    title: 'What you need',
    body: 'A little space, a mat, and a pair of meel. No meel yet? Start '
        'with Sheno Explosion: it needs none.',
  ),
  OnboardingCard(
    title: 'Train safely',
    body: 'Warm up first, go at your own pace, and stop if anything hurts. '
        'Next, we’ll ask you to agree to our safety and privacy terms.',
    builtinImage: BuiltinOnboardingImage.figureAlt,
  ),
];
