import 'package:equatable/equatable.dart';

/// The authenticated user, joined with their app-specific profile row.
class AppUser extends Equatable {
  final String id;
  final String email;
  final bool isTrainer;
  final bool hasConsented;

  const AppUser({
    required this.id,
    required this.email,
    this.isTrainer = false,
    this.hasConsented = false,
  });

  AppUser copyWith({bool? isTrainer, bool? hasConsented}) => AppUser(
        id: id,
        email: email,
        isTrainer: isTrainer ?? this.isTrainer,
        hasConsented: hasConsented ?? this.hasConsented,
      );

  @override
  List<Object?> get props => [id, email, isTrainer, hasConsented];
}
