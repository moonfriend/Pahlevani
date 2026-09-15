import 'package:equatable/equatable.dart';

/// A "Morshed" — one reciter/musician whose recordings an athlete can
/// choose to hear, everywhere, instead of a trainer-fixed recording.
class Morshed extends Equatable {
  final int id;
  final String name;
  final String? photoUrl;

  const Morshed({required this.id, required this.name, this.photoUrl});

  @override
  List<Object?> get props => [id, name, photoUrl];
}
