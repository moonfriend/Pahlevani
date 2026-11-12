import 'package:equatable/equatable.dart';

/// The signed-in user, joining Supabase auth identity with their
/// supabase/migrations/0013_profiles_and_consent.sql profile row.
class AppUser extends Equatable {
  final String id;
  final String? email;
  final bool isTrainer;
  final bool consentAccepted;
  final DateTime? consentedAt;

  /// The terms version accepted (null: accepted before versions existed).
  final int? termsVersion;

  /// Agreed to marketing emails (optional; never required to use the app).
  final bool marketingOptIn;

  /// A Steady account is linked (signed in with Steady at least once).
  final bool hasSteady;

  const AppUser({
    required this.id,
    this.email,
    this.isTrainer = false,
    this.consentAccepted = false,
    this.consentedAt,
    this.termsVersion,
    this.marketingOptIn = false,
    this.hasSteady = false,
  });

  /// Has accepted the safety terms and privacy summary at [version] or later.
  bool hasAcceptedTerms(int version) =>
      consentAccepted && (termsVersion ?? 0) >= version;

  AppUser copyWith({
    String? email,
    bool? isTrainer,
    bool? consentAccepted,
    DateTime? consentedAt,
    int? termsVersion,
    bool? marketingOptIn,
    bool? hasSteady,
  }) =>
      AppUser(
        id: id,
        email: email ?? this.email,
        isTrainer: isTrainer ?? this.isTrainer,
        consentAccepted: consentAccepted ?? this.consentAccepted,
        consentedAt: consentedAt ?? this.consentedAt,
        termsVersion: termsVersion ?? this.termsVersion,
        marketingOptIn: marketingOptIn ?? this.marketingOptIn,
        hasSteady: hasSteady ?? this.hasSteady,
      );

  @override
  List<Object?> get props => [
        id,
        email,
        isTrainer,
        consentAccepted,
        consentedAt,
        termsVersion,
        marketingOptIn,
        hasSteady
      ];
}
