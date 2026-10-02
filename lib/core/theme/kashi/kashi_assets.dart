/// Bundled Kashi brand and illustration assets (from the design handoff,
/// resized/converted to keep app size down).
abstract final class KashiAssets {
  /// Rahavi logo — transparent, azure and yellow.
  static const rahaviLogo = 'assets/brand/rahavi_logo.png';
  static const rahaviMark = 'assets/brand/rahavi_mark.png';

  /// The user's illustrations; a random one is used per session on splash,
  /// onboarding, the Home hero and the avatar.
  static const pahlevanMale = 'assets/illustrations/pahlevan_m.webp';
  static const pahlevanFemale = 'assets/illustrations/pahlevan_f.webp';

  static const all = [rahaviLogo, rahaviMark, pahlevanMale, pahlevanFemale];
}
