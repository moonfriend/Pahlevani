// PLACEHOLDER WORDING — replace with the lawyer-checked texts before release
// (release 1 plan, block E). When the wording changes in a way users must
// agree to again, also bump `currentTermsVersion`
// (lib/domain/entities/auth/consent.dart).

/// Short, readable summaries shown on the consent screen. The full texts are
/// linked from it.
abstract final class ConsentTexts {
  static const safetyTitle = 'Safety';
  static const safetyPoints = [
    'I train at my own risk.',
    'I’ll check with a doctor first if I have a health condition.',
    'I’ll stop if I feel pain, and warm up before training.',
  ];
  static const safetyCheckbox = 'I understand and accept the safety terms.';

  static const privacyTitle = 'Your data';
  static const privacyPoints = [
    'We store your email, your activation code and when you trained.',
    'It is kept with our database provider in the EU.',
    'You can delete your account and its data at any time in Profile.',
  ];
  static const privacyCheckbox = 'I accept the privacy policy.';

  static const marketingCheckbox =
      'Send me occasional emails about new sessions and offers (optional).';

  /// The full texts on our website.
  static const termsUrl = 'https://rahaavi.com/terms';
  static const privacyUrl = 'https://rahaavi.com/privacy';
}
