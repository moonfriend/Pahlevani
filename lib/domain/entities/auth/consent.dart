/// The version of the safety terms and privacy summary users must have agreed
/// to, as far as the app itself knows. The server's value (admin, migration
/// 0049) wins whenever it can be read; this is only the offline fallback, so
/// keep it at the version the shipped texts in consent_texts.dart belong to.
const currentTermsVersion = 2;

/// When the texts of [currentTermsVersion] were published on rahaavi.com.
final currentTermsUpdatedOn = DateTime(2026, 10, 25);
