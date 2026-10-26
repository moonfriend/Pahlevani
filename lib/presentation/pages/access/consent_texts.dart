// Short summaries of the terms and privacy policy published on rahaavi.com
// (both "last updated 25 October 2026"); the safety points follow the terms'
// section 3, "Training at your own risk". When the website's texts change,
// update these, then raise the terms version in admin (Activation tab) so
// everyone is asked to agree again — and `currentTermsVersion`
// (lib/domain/entities/auth/consent.dart) with the next release.

/// Short, readable summaries shown when agreeing. The full texts are linked.
abstract final class ConsentTexts {
  static const safetyTitle = 'Safety';
  static const safetyPoints = [
    'Gowd teaches a traditional movement practice. It is not a health or '
        'fitness app and can’t assess my health.',
    'I’ll talk to a doctor before I start, especially if I have a health '
        'condition or am pregnant.',
    'I’ll warm up, go at my own pace and rest when I need to.',
    'If a movement hurts, I’ll stop and not push through. I train at my own '
        'risk.',
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
