import 'package:equatable/equatable.dart';

/// A "Morshed" — one reciter/musician whose recordings an athlete can
/// choose to hear, everywhere, instead of a trainer-fixed recording.
class Musician extends Equatable {
  final int id;
  final String name;
  final String? photoUrl;

  /// True for the one performer exercise-demonstration videos are timed
  /// against (their "sarzarb"/beat anchors) — currently Sirvan Norouzi.
  /// Choosing any other Morshed can leave video and audio out of sync.
  final bool isVideoReference;

  const Musician({
    required this.id,
    required this.name,
    this.photoUrl,
    this.isVideoReference = false,
  });

  @override
  List<Object?> get props => [id, name, photoUrl, isVideoReference];
}
