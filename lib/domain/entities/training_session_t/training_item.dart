/// Represents a single song within a training_session, based on the provided JSON structure.
//Design note: for now this is just one media. Later we will have media assets 
// be properties of an Exercise
// class Exercise { //TODO: convert to training_item or what makes sense(consider filename)
//   final int id;
//   final String name;
//   final String author;
//   final String type;
//   final String audioUrl; // Assuming this is the audio source URL
//   final int position;
//   //TODO: this needs the reps
//
//   Exercise({
//     required this.id,
//     required this.name,
//     required this.author,
//     required this.type,
//     required this.audioUrl,
//     required this.position,
//   });
//
//   // Factory constructor to create a Song from a map (like the JSON data)
//   factory Exercise.fromJson(Map<String, dynamic> json) {
//     return Exercise(
//       id: json['id'] as int? ?? 0,
//       name: json['name'] as String? ?? 'Unknown Song',
//       author: json['author'] as String? ?? 'Unknown Artist',
//       type: json['type'] as String? ?? 'Unknown Type',
//       audioUrl: json['url'] as String? ?? '',
//       position: json['position'] as int? ?? 0,
//     );
//   }
// }
