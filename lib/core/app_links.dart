/// Pages on our website the app links to. They live on the site so their
/// content can change without an app release.
abstract final class AppLinks {
  static const meelGuide = 'https://rahaavi.com/meel/';

  /// Who we are.
  static const rahavi = 'https://rahaavi.com/';

  /// Legal pages. German law wants the Impressum and the privacy notice
  /// reachable from anywhere in the app, not only at sign-up — see
  /// RahaviMenuButton.
  static const privacy = 'https://rahaavi.com/privacy';
  static const impressum = 'https://rahaavi.com/impressum';
  static const terms = 'https://rahaavi.com/terms';
}
