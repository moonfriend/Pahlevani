import 'package:equatable/equatable.dart';

/// A "Morshed" — one reciter/musician whose recordings an athlete can
/// choose to hear, everywhere, instead of a trainer-fixed recording.
class Morshed extends Equatable {
  final int id;
  final String name;
  final String? photoUrl;

  /// The Morshed a first-time user gets before choosing one (set by the
  /// admin; at most one is true — migration 0041).
  final bool isDefault;

  const Morshed(
      {required this.id,
      required this.name,
      this.photoUrl,
      this.isDefault = false});

  @override
  List<Object?> get props => [id, name, photoUrl, isDefault];
}
