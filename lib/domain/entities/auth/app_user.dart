import 'package:equatable/equatable.dart';

/// The signed-in user, joining Supabase auth identity with their
/// supabase/migrations/0013_profiles_and_consent.sql profile row.
class AppUser extends Equatable {
  final String id;
  final String? email;
  final bool isTrainer;
  final bool consentAccepted;
  final DateTime? consentedAt;

  const AppUser({
    required this.id,
    this.email,
    this.isTrainer = false,
    this.consentAccepted = false,
    this.consentedAt,
  });

  AppUser copyWith({
    String? email,
    bool? isTrainer,
    bool? consentAccepted,
    DateTime? consentedAt,
  }) =>
      AppUser(
        id: id,
        email: email ?? this.email,
        isTrainer: isTrainer ?? this.isTrainer,
        consentAccepted: consentAccepted ?? this.consentAccepted,
        consentedAt: consentedAt ?? this.consentedAt,
      );

  @override
  List<Object?> get props =>
      [id, email, isTrainer, consentAccepted, consentedAt];
}
